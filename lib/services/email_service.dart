import 'package:cloud_firestore/cloud_firestore.dart';

/// Booking confirmation email — queues a document for the Firebase
/// "Trigger Email" Extension (watches the `mail` collection, sends via
/// Gmail SMTP) instead of calling EmailJS directly.
///
/// Success here only means the document was queued, not that the email was
/// actually delivered — the Extension sends asynchronously a few seconds
/// later. Check the doc's `delivery.state` field for actual send status.
class EmailService {
  static Future<void> sendBookingEmail({
    required String email,
    required String className,
    required String classTime,
  }) async {
    await FirebaseFirestore.instance.collection('mail').add({
      'to': [email],
      'message': {
        'subject': 'Booking Confirmed — $className',
        'html': '''
          <div style="font-family: sans-serif; color: #0A0A0A;">
            <h2 style="color: #FF7A00;">Booking Confirmed</h2>
            <p>Your booking for <strong>$className</strong> at <strong>$classTime</strong> is confirmed.</p>
            <p>See you there!</p>
          </div>
        ''',
      },
    });
  }
}
