import 'dart:developer';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_paystack_plus/flutter_paystack_plus.dart';
import 'package:autobus/config/app_config.dart';

class PaystackService {
  static final PaystackService _instance = PaystackService._internal();
  factory PaystackService() => _instance;
  PaystackService._internal();

  /// For subscriptions, pass a [planCode] (e.g. PLN_xxxx from dashboard).
  /// For one-time payments, leave [planCode] null and pass [amount] in pesewas.
  Future<String?> launch({
    required BuildContext context,
    required String email,
    required String reference,
    required String authorizationUrl,
    String? planCode, // pass this for subscriptions
    num? amount, // major units; converted to subunits for Paystack
    String currency = 'GHS', // change to NGN, USD etc as needed
    required String callbackUrl,
    required Future<void> Function() onSuccess,
    required Future<void> Function() onCancelled,
  }) async {
    try {
      await FlutterPaystackPlus.openPaystackPopup(
        context: context,
        publicKey: AppConfig.paystackPublicKey,
        customerEmail: email,
        amount: amount != null ? (amount * 100).round().toString() : '0',
        reference: reference,
        authorizationUrl: authorizationUrl,
        currency: currency,
        plan: planCode,
        callBackUrl: callbackUrl,
        onSuccess: () => unawaited(onSuccess()),
        onClosed: () => unawaited(onCancelled()),
      );
      return reference;
    } catch (e) {
      log('Paystack error: $e');
      return null;
    }
  }
}
