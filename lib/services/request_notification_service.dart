import 'package:cloud_firestore/cloud_firestore.dart';

/// Emails around the adminRequests lifecycle (credit_request, slot_increase,
/// session_cancel, appointment_booking) — submission notifies admins (no
/// push notification exists for "you have a new request to review"),
/// resolution notifies whoever submitted it. Both are best-effort: a
/// failure here should never block the underlying request/resolve action.
class RequestNotificationService {
  static final _db = FirebaseFirestore.instance;

  static Future<void> notifyAdminsOfNewRequest({
    required String typeLabel,
    required String requesterName,
    required String summary,
  }) async {
    try {
      final adminSnap =
          await _db.collection('users').where('role', isEqualTo: 'admin').get();
      final emails = adminSnap.docs
          .map((d) => d.data()['email']?.toString() ?? '')
          .where((e) => e.isNotEmpty)
          .toList();
      if (emails.isEmpty) return;
      await _db.collection('mail').add({
        'to': emails,
        'message': {
          'subject': 'New $typeLabel — $requesterName',
          'html': '''
            <div style="font-family: sans-serif; color: #0A0A0A;">
              <h2 style="color: #FF7A00;">New $typeLabel</h2>
              <p><strong>$requesterName</strong> submitted a $typeLabel.</p>
              <p>$summary</p>
              <p>Review it in the admin app under Pending Requests.</p>
            </div>
          ''',
        },
      });
    } catch (_) {
      // Best-effort — never block request submission.
    }
  }

  static Future<void> notifyRequesterOfResolution({
    required String requesterUid,
    required String typeLabel,
    required bool approved,
    String outcomeLabel = '',
    String note = '',
  }) async {
    try {
      final userDoc = await _db.collection('users').doc(requesterUid).get();
      final email = userDoc.data()?['email']?.toString() ?? '';
      if (email.isEmpty) return;
      final status = outcomeLabel.isNotEmpty
          ? outcomeLabel
          : (approved ? 'Approved' : 'Rejected');
      await _db.collection('mail').add({
        'to': [email],
        'message': {
          'subject': '$typeLabel — $status',
          'html': '''
            <div style="font-family: sans-serif; color: #0A0A0A;">
              <h2 style="color: ${approved ? '#00D4AA' : '#E53935'};">$typeLabel $status</h2>
              <p>Your $typeLabel has been ${status.toLowerCase()}${note.isNotEmpty ? ':<br>$note' : '.'}</p>
            </div>
          ''',
        },
      });
    } catch (_) {
      // Best-effort — never block request resolution.
    }
  }
}
