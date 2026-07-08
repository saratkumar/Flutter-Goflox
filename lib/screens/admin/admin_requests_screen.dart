import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../models/admin_request_model.dart';
import '../../models/user_model.dart';
import '../../services/user_service.dart';
import '../../services/class_service.dart';
import '../../services/notifications.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_toast.dart';

class AdminRequestsScreen extends StatefulWidget {
  const AdminRequestsScreen({super.key});

  @override
  State<AdminRequestsScreen> createState() => _AdminRequestsScreenState();
}

class _AdminRequestsScreenState extends State<AdminRequestsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Requests'),
        bottom: TabBar(
          controller: _tab,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.textPrimary,
          unselectedLabelColor: AppColors.textMuted,
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Resolved'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _RequestList(statusFilter: 'pending'),
          _RequestList(statusFilter: null, excludePending: true),
        ],
      ),
    );
  }
}

class _RequestList extends StatelessWidget {
  final String? statusFilter;
  final bool excludePending;

  const _RequestList({this.statusFilter, this.excludePending = false});

  @override
  Widget build(BuildContext context) {
    // When filtering by status, skip orderBy to avoid composite index — sort in Dart
    final stream = statusFilter != null
        ? FirebaseFirestore.instance
            .collection('adminRequests')
            .where('status', isEqualTo: statusFilter)
            .snapshots()
        : FirebaseFirestore.instance
            .collection('adminRequests')
            .orderBy('createdAt', descending: true)
            .snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Center(
              child: CircularProgressIndicator(color: AppColors.primary));
        }
        var docs = snap.data?.docs ?? [];
        if (excludePending) {
          docs = docs
              .where((d) => (d['status'] as String?) != 'pending')
              .toList();
        }
        // Sort newest-first in Dart
        docs.sort((a, b) {
          final ta = (a['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
          final tb = (b['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
          return tb.compareTo(ta);
        });
        if (docs.isEmpty) {
          return const Center(
            child: Text('No requests',
                style: TextStyle(color: AppColors.textSecondary)),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(14),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final req = AdminRequestModel.fromFirestore(docs[i]);
            return _RequestCard(request: req);
          },
        );
      },
    );
  }
}

// ── Request card ──────────────────────────────────────────────────────────────

class _RequestCard extends StatefulWidget {
  final AdminRequestModel request;
  const _RequestCard({required this.request});

  @override
  State<_RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends State<_RequestCard> {
  bool _processing = false;

  AdminRequestModel get req => widget.request;

  // ── Helpers ────────────────────────────────────────────────────────────────

  Color get _statusColor {
    switch (req.status) {
      case 'approved':
      case 'approved_cancel':
      case 'reassigned':
        return const Color(0xFF00D4AA);
      case 'rejected':
        return AppColors.error;
      default:
        return const Color(0xFFFFAB40);
    }
  }

  String get _statusLabel {
    switch (req.status) {
      case 'approved_cancel':
        return 'CANCELLED';
      case 'reassigned':
        return 'REASSIGNED';
      default:
        return req.status.toUpperCase();
    }
  }

  String get _typeLabel {
    switch (req.type) {
      case 'credit_request':
        return 'Credit Request';
      case 'session_cancel':
        return 'Session Cancellation Request';
      default:
        return 'Slot Increase Request';
    }
  }

  // ── Standard approve / reject (credit_request & slot_increase) ────────────

  Future<void> _resolve(bool approved) async {
    setState(() => _processing = true);
    try {
      final adminUid = FirebaseAuth.instance.currentUser?.uid ?? '';
      await FirebaseFirestore.instance
          .collection('adminRequests')
          .doc(req.id)
          .update({
        'status': approved ? 'approved' : 'rejected',
        'resolvedAt': Timestamp.now(),
        'resolvedBy': adminUid,
      });

      if (approved) {
        if (req.type == 'credit_request' && req.targetUserId != null) {
          await UserService.addCredits(req.targetUserId!, req.amount);
        } else if (req.type == 'slot_increase' && req.classId != null) {
          final cls = await ClassService.getClass(req.classId!);
          if (cls != null) {
            final sessionDate = req.sessionDate;
            if (sessionDate != null) {
              // Temporary override — does NOT change the permanent groupSize
              final newCap =
                  (int.tryParse(cls.groupSize) ?? 0) + req.amount;
              await FirebaseFirestore.instance
                  .collection('classes')
                  .doc(req.classId)
                  .update({'sessionSlotOverrides.$sessionDate': newCap});
              // Log it
              await FirebaseFirestore.instance
                  .collection('sessionLogs')
                  .add({
                'type': 'slot_override',
                'classId': req.classId,
                'className': req.className ?? '',
                'sessionDate': sessionDate,
                'extraSlots': req.amount,
                'newCapacity': newCap,
                'requestId': req.id,
                'requestedBy': req.requestedByName,
                'createdAt': Timestamp.now(),
              });
            } else {
              // Legacy request without sessionDate — still do permanent update
              await ClassService.updateGroupSize(
                  req.classId!, (int.tryParse(cls.groupSize) ?? 0) + req.amount);
            }
          }
        }
      }

      if (mounted) {
        AppToast.success(context, approved ? 'Request approved' : 'Request rejected');
      }
    } catch (e) {
      if (mounted) AppToast.error(context, 'Failed: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  // ── Approve cancellation (session_cancel) ─────────────────────────────────

  Future<void> _approveSessionCancel() async {
    setState(() => _processing = true);
    try {
      final adminUid = FirebaseAuth.instance.currentUser?.uid ?? '';

      if (req.classId != null && req.sessionDate != null) {
        final parts = req.sessionDate!.split('-');
        if (parts.length == 3) {
          final date = DateTime(
              int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
          final end = date.add(const Duration(days: 1));

          // Fetch all bookings for the class, filter session date in Dart
          final allSnap = await FirebaseFirestore.instance
              .collection('bookings')
              .where('classId', isEqualTo: req.classId)
              .get();
          final sessionDocs = allSnap.docs.where((d) {
            if (d['status'] == 'cancelled_by_trainer') return false;
            final bd = d['bookingDate'];
            if (bd == null) return false;
            final dt = (bd as Timestamp).toDate();
            return !dt.isBefore(date) && dt.isBefore(end);
          }).toList();

          // Mark bookings cancelled
          final batch = FirebaseFirestore.instance.batch();
          for (final doc in sessionDocs) {
            batch.update(doc.reference, {'status': 'cancelled_by_trainer'});
          }
          await batch.commit();

          // Refund credits in parallel
          final refunds = <Future>[];
          for (final doc in sessionDocs) {
            final uid = doc['userId'] as String?;
            final credits = doc['creditsUsed'] as int? ?? 1;
            if (uid != null && credits > 0) {
              refunds.add(UserService.addCredits(uid, credits));
            }
          }
          if (refunds.isNotEmpty) await Future.wait(refunds);

          // Notify clients
          if (sessionDocs.isNotEmpty) {
            await NotificationService.showSessionCancelApproved(
                req.className ?? 'session');
          }
        }
      }

      // Mark the session date as cancelled on the class document
      if (req.classId != null && req.sessionDate != null) {
        // Fetch class to check occurrence type
        final clsSnap = await FirebaseFirestore.instance
            .collection('classes')
            .doc(req.classId)
            .get();
        final isOnce = (clsSnap.data()?['occurrence'] as String?) == 'once';

        await FirebaseFirestore.instance
            .collection('classes')
            .doc(req.classId)
            .update(isOnce
                // One-off class: deactivate entirely so it disappears everywhere
                ? {'isActive': false, 'updatedAt': FieldValue.serverTimestamp()}
                // Recurring class: only block that specific date
                : {
                    'cancelledDates':
                        FieldValue.arrayUnion([req.sessionDate]),
                    'updatedAt': FieldValue.serverTimestamp(),
                  });

        // Write audit log
        await FirebaseFirestore.instance.collection('sessionLogs').add({
          'type': 'session_cancelled',
          'classId': req.classId,
          'className': req.className ?? '',
          'coach': req.requestedByName,
          'sessionDate': req.sessionDate,
          'cancelledAt': Timestamp.now(),
          'cancelledBy': adminUid,
          'reason': 'trainer_request',
          'requestId': req.id,
          'classDeactivated': isOnce,
        });
      }

      await FirebaseFirestore.instance
          .collection('adminRequests')
          .doc(req.id)
          .update({
        'status': 'approved_cancel',
        'resolvedAt': Timestamp.now(),
        'resolvedBy': adminUid,
      });

      if (mounted) {
        AppToast.success(
            context, 'Cancellation approved — bookings cancelled & credits refunded');
      }
    } catch (e, st) {
      debugPrint('_approveSessionCancel: $e\n$st');
      if (mounted) AppToast.error(context, 'Failed: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  // ── Reassign trainer (session_cancel) ─────────────────────────────────────

  Future<void> _reassignTrainer() async {
    // Load coaches then show picker
    List<UserModel> coaches;
    try {
      coaches = await ClassService.getCoaches();
    } catch (e) {
      if (mounted) AppToast.error(context, 'Could not load trainers');
      return;
    }
    if (!mounted) return;

    final selected = await showDialog<UserModel>(
      context: context,
      builder: (ctx) => _TrainerPickerDialog(
        coaches: coaches,
        currentCoach: req.requestedByName,
      ),
    );
    if (selected == null || !mounted) return;

    setState(() => _processing = true);
    try {
      final adminUid = FirebaseAuth.instance.currentUser?.uid ?? '';

      // Update class coach permanently
      if (req.classId != null) {
        await ClassService.updateCoach(req.classId!, selected.name);
      }

      // Notify old trainer they've been removed
      await NotificationService.showTrainerRemoved(req.className ?? '');
      // Notify new trainer they've been assigned
      await NotificationService.showTrainerAssigned(
          req.className ?? '', req.sessionDate ?? '');

      // Mark request resolved
      await FirebaseFirestore.instance
          .collection('adminRequests')
          .doc(req.id)
          .update({
        'status': 'reassigned',
        'resolvedAt': Timestamp.now(),
        'resolvedBy': adminUid,
        'newTrainer': selected.name,
      });

      if (mounted) {
        AppToast.success(context, 'Session reassigned to ${selected.name}');
      }
    } catch (e, st) {
      debugPrint('_reassignTrainer: $e\n$st');
      if (mounted) AppToast.error(context, 'Failed: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  // ── Info row helper ────────────────────────────────────────────────────────

  Widget _info(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text('$label:',
                style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isPending = req.status == 'pending';
    final isSessionCancel = req.type == 'session_cancel';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isPending
                ? const Color(0xFFFFAB40).withValues(alpha: 0.4)
                : AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title + status badge
          Row(
            children: [
              Expanded(
                child: Text(
                  _typeLabel,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _statusLabel,
                  style: TextStyle(
                      fontSize: 10,
                      color: _statusColor,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Info rows — vary by type
          if (isSessionCancel) ...[
            _info('Trainer', req.requestedByName),
            _info('Class', req.className ?? '—'),
            _info('Session Date', req.sessionDate ?? '—'),
            if (req.newTrainer != null) _info('New Trainer', req.newTrainer!),
          ] else if (req.type == 'credit_request') ...[
            _info('Trainer', req.requestedByName),
            _info('Client', req.targetUserName ?? '—'),
            _info('Credits requested', '${req.amount}'),
          ] else ...[
            _info('Trainer', req.requestedByName),
            _info('Class', req.className ?? '—'),
            _info('Extra slots requested', '${req.amount}'),
          ],

          if (req.note.isNotEmpty) ...[
            const SizedBox(height: 3),
            _info('Note', req.note),
          ],

          // Action buttons — only for pending requests
          if (isPending) ...[
            const SizedBox(height: 14),
            if (_processing)
              const Center(
                  child: SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.primary)))
            else if (isSessionCancel)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _approveSessionCancel,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF00D4AA),
                        side: const BorderSide(color: Color(0xFF00D4AA)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Approve Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _reassignTrainer,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Reassign Trainer'),
                    ),
                  ),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _resolve(false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: BorderSide(
                            color: AppColors.error.withValues(alpha: 0.5)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Reject'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _resolve(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00D4AA),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Approve'),
                    ),
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }
}

// ── Trainer picker dialog ─────────────────────────────────────────────────────

class _TrainerPickerDialog extends StatelessWidget {
  final List<UserModel> coaches;
  final String currentCoach;

  const _TrainerPickerDialog(
      {required this.coaches, required this.currentCoach});

  @override
  Widget build(BuildContext context) {
    final available =
        coaches.where((c) => c.name != currentCoach).toList();

    return AlertDialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Text('Assign New Trainer',
          style: TextStyle(
              color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
      content: SizedBox(
        width: double.maxFinite,
        child: available.isEmpty
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('No other trainers available.',
                    style: TextStyle(color: AppColors.textSecondary)),
              )
            : ListView.separated(
                shrinkWrap: true,
                itemCount: available.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, color: AppColors.divider),
                itemBuilder: (ctx, i) {
                  final coach = available[i];
                  return ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFF1A1A2E),
                      child: Icon(Icons.person_outline,
                          color: AppColors.primary, size: 20),
                    ),
                    title: Text(coach.name,
                        style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600)),
                    subtitle: Text(coach.role,
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 12)),
                    onTap: () => Navigator.pop(ctx, coach),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel',
              style: TextStyle(color: AppColors.textMuted)),
        ),
      ],
    );
  }
}
