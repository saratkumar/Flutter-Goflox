import 'package:cloud_firestore/cloud_firestore.dart';
import 'config_service.dart';

class InvoiceService {
  /// Derives the invoice number from the Stripe [paymentIntentId] (globally
  /// unique) instead of a timestamp modulo, which previously repeated every
  /// 10 seconds and could hand two different payments the same number.
  static String generateInvoiceNumber(String paymentIntentId) {
    final now = DateTime.now();
    final ref = paymentIntentId.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    final suffix =
        (ref.length >= 8 ? ref.substring(ref.length - 8) : ref.padLeft(8, '0'))
            .toUpperCase();
    return 'PSAS-'
        '${now.year}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}'
        '-$suffix';
  }

  /// Records the transaction in the Google Sheet Transactions tab and sends
  /// an invoice email via EmailJS. The Sheet write is best-effort (failures
  /// are swallowed since it's a secondary record), but returns whether the
  /// invoice email itself succeeded — plus the raw error detail on failure —
  /// so the caller can surface a diagnosable message instead of a silent drop.
  static Future<(bool sent, String? error)> processWithInvoice({
    required String invoiceNumber,
    required String paymentIntentId,
    required String clientName,
    required String clientEmail,
    required String planName,
    required int credits,
    required double amount,
    required String currency,
  }) async {
    final now = DateTime.now();
    final dateStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    var emailSent = false;
    String? error;
    await Future.wait([
      _recordToSheet(
        invoiceNumber: invoiceNumber,
        paymentIntentId: paymentIntentId,
        clientName: clientName,
        clientEmail: clientEmail,
        planName: planName,
        credits: credits,
        amount: amount,
        currency: currency,
        date: dateStr,
      ).catchError((_) {}),
      () async {
        try {
          await _sendEmail(
            invoiceNumber: invoiceNumber,
            clientName: clientName,
            clientEmail: clientEmail,
            planName: planName,
            credits: credits,
            amount: amount,
            currency: currency,
            paymentIntentId: paymentIntentId,
            date: dateStr,
          );
          emailSent = true;
        } catch (e) {
          error = e.toString();
        }
      }(),
    ]);
    return (emailSent, error);
  }

  static Future<void> _recordToSheet({
    required String invoiceNumber,
    required String paymentIntentId,
    required String clientName,
    required String clientEmail,
    required String planName,
    required int credits,
    required double amount,
    required String currency,
    required String date,
  }) async {
    await ConfigService.recordTransaction(
      invoiceNumber: invoiceNumber,
      paymentIntentId: paymentIntentId,
      clientName: clientName,
      clientEmail: clientEmail,
      planName: planName,
      credits: credits,
      amount: amount,
      currency: currency,
      date: date,
    );
  }

  /// Queues an invoice email via the Firebase "Trigger Email" Extension
  /// (watches the `mail` collection, sends via Gmail SMTP) instead of
  /// calling EmailJS directly. Success here only means the document was
  /// queued, not that the email was actually delivered.
  static Future<void> _sendEmail({
    required String invoiceNumber,
    required String clientName,
    required String clientEmail,
    required String planName,
    required int credits,
    required double amount,
    required String currency,
    required String paymentIntentId,
    required String date,
  }) async {
    await FirebaseFirestore.instance.collection('mail').add({
      'to': [clientEmail],
      'message': {
        'subject': 'Invoice $invoiceNumber — PSAS',
        'html': '''
          <div style="font-family: sans-serif; color: #0A0A0A;">
            <h2 style="color: #FF7A00;">Invoice $invoiceNumber</h2>
            <p>Date: $date</p>
            <p>Plan: $planName ($credits credits)</p>
            <p>Amount: $currency ${amount.toStringAsFixed(2)}</p>
            <p>Payment Ref: $paymentIntentId</p>
            <p>Thank you, $clientName.</p>
          </div>
        ''',
      },
    });
  }
}
