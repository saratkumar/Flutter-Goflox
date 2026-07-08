import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';

class TrainerRequestsScreen extends StatelessWidget {
  const TrainerRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        // No orderBy with where — composite index required; sort in Dart instead
        stream: FirebaseFirestore.instance
            .collection('adminRequests')
            .where('requestedBy', isEqualTo: uid)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.primary));
          }
          final raw = snap.data?.docs ?? [];
          final docs = List.of(raw)
            ..sort((a, b) {
              final ta =
                  (a['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
              final tb =
                  (b['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
              return tb.compareTo(ta);
            });
          if (docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox_outlined,
                      size: 56, color: AppColors.textMuted),
                  SizedBox(height: 14),
                  Text('No requests yet',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 15)),
                  SizedBox(height: 6),
                  Text(
                    'Slot increase, credit, and\ncancellation requests will appear here.',
                    style:
                        TextStyle(color: AppColors.textMuted, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(14),
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final data = docs[i].data() as Map<String, dynamic>;
              final type = data['type'] as String? ?? '';
              final status = data['status'] as String? ?? 'pending';

              // Status colour — approved_cancel and reassigned both count as resolved
              final Color statusColor;
              switch (status) {
                case 'approved':
                case 'approved_cancel':
                case 'reassigned':
                  statusColor = const Color(0xFF00D4AA);
                case 'rejected':
                  statusColor = AppColors.error;
                default:
                  statusColor = const Color(0xFFFFAB40);
              }

              // Human-readable status badge text
              final String statusLabel;
              switch (status) {
                case 'approved_cancel':
                  statusLabel = 'CANCELLED';
                case 'reassigned':
                  statusLabel = 'REASSIGNED';
                default:
                  statusLabel = status.toUpperCase();
              }

              // Request-submitted date (createdAt)
              final createdAt = data['createdAt'];
              String submittedStr = '';
              if (createdAt is Timestamp) {
                final d = createdAt.toDate();
                const months = [
                  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
                ];
                submittedStr = '${d.day} ${months[d.month - 1]} ${d.year}';
              }

              // Icon + title + subtitle vary by type
              final IconData typeIcon;
              final String title;
              final String subtitle;
              switch (type) {
                case 'session_cancel':
                  typeIcon = Icons.cancel_outlined;
                  title =
                      'Cancel Session — ${data['className'] ?? ''}';
                  final sessionDate =
                      data['sessionDate'] as String? ?? '';
                  final newTrainer =
                      data['newTrainer'] as String?;
                  if (status == 'reassigned' && newTrainer != null) {
                    subtitle = 'Reassigned to $newTrainer'
                        '${sessionDate.isNotEmpty ? ' • $sessionDate' : ''}';
                  } else {
                    subtitle = sessionDate.isNotEmpty
                        ? 'Session date: $sessionDate'
                        : 'Pending admin review';
                  }
                case 'credit_request':
                  typeIcon = Icons.toll_outlined;
                  title =
                      'Credit Request — ${data['targetUserName'] ?? ''}';
                  subtitle = '+${data['amount']} credits';
                default:
                  typeIcon = Icons.add_box_outlined;
                  title = 'Slot Increase — ${data['className'] ?? ''}';
                  subtitle = '+${data['amount']} slots';
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Row(
                  children: [
                    // Icon pill
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(typeIcon, color: statusColor, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                                fontSize: 14),
                          ),
                          const SizedBox(height: 3),
                          Text(subtitle,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary)),
                          if (submittedStr.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text('Submitted $submittedStr',
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textMuted)),
                          ],
                          if ((data['note'] as String? ?? '').isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(data['note'],
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textMuted,
                                    fontStyle: FontStyle.italic)),
                          ],
                        ],
                      ),
                    ),
                    // Status badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                            fontSize: 10,
                            color: statusColor,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
