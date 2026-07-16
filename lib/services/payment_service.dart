import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

class PaymentService {
  // Safe to include in client code. Swap pk_test_ → pk_live_ for production.
  // Get yours from: https://dashboard.stripe.com/test/apikeys
  static const _publishableKey =
      'pk_test_51Tps5X5GDQ6NbhM7JIa90Yh2ce52faber57nbE9GJB4kZFS7QpxjF4nWO0RxNmWcs8kPNWAFX4vG2WcGKt5irYzu00nf4mQiQu';

  // Cloud Functions are deployed to asia-southeast1 (see functions/index.js
  // setGlobalOptions) — the default FirebaseFunctions.instance targets
  // us-central1 and would silently fail to find any of these functions.
  static final _functions =
      FirebaseFunctions.instanceFor(region: 'asia-southeast1');

  static bool _initialized = false;

  /// Initializes the Stripe SDK on first use instead of at app startup, so
  /// clients who never open the payment flow don't pay its memory/CPU cost.
  static Future<void> _ensureInitialized() async {
    if (_initialized) return;
    Stripe.publishableKey = _publishableKey;
    await Stripe.instance.applySettings();
    _initialized = true;
  }

  /// Creates the PaymentIntent server-side (via the `createPaymentIntent`
  /// Cloud Function — the Stripe secret key never touches the client) →
  /// shows the payment sheet to the user.
  ///
  /// Throws [StripeException] if user cancels.
  /// Throws on network/Cloud Function errors.
  /// Returns the Stripe PaymentIntent ID (pi_xxx) on success.
  static Future<String> processPayment({
    required String planName,
    required double amount,
    required String currency,
  }) async {
    await _ensureInitialized();

    final result = await _functions.httpsCallable('createPaymentIntent').call({
      'amount': amount,
      'currency': currency,
      'planName': planName,
    });
    final data = result.data as Map;
    final clientSecret = data['clientSecret'] as String;
    final paymentIntentId = data['paymentIntentId'] as String;

    await Stripe.instance.initPaymentSheet(
      paymentSheetParameters: SetupPaymentSheetParameters(
        paymentIntentClientSecret: clientSecret,
        merchantDisplayName: 'PSAS',
        style: ThemeMode.light,
        appearance: const PaymentSheetAppearance(
          colors: PaymentSheetAppearanceColors(
            primary: Color(0xFFFF7A00),
          ),
        ),
        // PayNow (and other SG-local payment methods surfaced via
        // automatic_payment_methods) requires a Singapore billing address —
        // all customers are local, so prefill it instead of asking.
        billingDetails: const BillingDetails(
          address: Address(
            city: null,
            country: 'SG',
            line1: null,
            line2: null,
            postalCode: null,
            state: null,
          ),
        ),
      ),
    );

    // Throws StripeException with code Canceled if user dismisses
    await Stripe.instance.presentPaymentSheet();

    return paymentIntentId;
  }

  /// Overwrites the PaymentIntent's description (initially set to the plan
  /// name at creation, before the invoice number exists) so the Stripe
  /// Dashboard shows the invoice number instead. Best-effort — the invoice
  /// itself is already recorded in Firestore regardless of this call.
  static Future<void> setInvoiceDescription(
      String paymentIntentId, String invoiceNumber) async {
    await _functions.httpsCallable('updatePaymentDescription').call({
      'paymentIntentId': paymentIntentId,
      'description': invoiceNumber,
    });
  }

  /// Verifies the payment succeeded server-side and activates the
  /// membership — replaces trusting the client's own Firestore write.
  static Future<void> confirmMembershipPayment({
    required String paymentIntentId,
    required String planName,
    required int credits,
    required int validityDays,
  }) async {
    await _functions.httpsCallable('confirmMembershipPayment').call({
      'paymentIntentId': paymentIntentId,
      'planName': planName,
      'credits': credits,
      'validityDays': validityDays,
    });
  }

  /// Validates and redeems a 100%-off coupon server-side, then activates
  /// the membership — replaces trusting the client's own coupon validation.
  static Future<void> redeemFreeMembership({
    required String planName,
    required int credits,
    required int validityDays,
    required String couponCode,
  }) async {
    await _functions.httpsCallable('redeemFreeMembership').call({
      'planName': planName,
      'credits': credits,
      'validityDays': validityDays,
      'couponCode': couponCode,
    });
  }
}
