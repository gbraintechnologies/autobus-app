import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static late String _backendUrl;
  static late String paystackPublicKey;
  static late String paystackCallbackUrl;

  static Future<void> init() async {
    try {
      await dotenv.load(fileName: '.env');
    } catch (e) {
      debugPrint('AppConfig: .env not loaded ($e); using dart-define/defaults');
    }

    const defineBackendUrl = String.fromEnvironment('BACKEND_URL');
    final envBackendUrl = dotenv.env['BACKEND_URL']?.trim();
    if (defineBackendUrl.isNotEmpty) {
      _backendUrl = defineBackendUrl;
    } else if (envBackendUrl != null && envBackendUrl.isNotEmpty) {
      _backendUrl = envBackendUrl;
    } else {
      _backendUrl = 'http://localhost:8000';
    }

    const definePaystackKey = String.fromEnvironment('PAYSTACK_PUBLIC_KEY');
    paystackPublicKey = definePaystackKey.isNotEmpty
        ? definePaystackKey
        : (dotenv.env['PAYSTACK_PUBLIC_KEY']?.trim() ?? '');

    const definePaystackCallback =
        String.fromEnvironment('PAYSTACK_CALLBACK_URL');
    paystackCallbackUrl = definePaystackCallback.isNotEmpty
        ? definePaystackCallback
        : (dotenv.env['PAYSTACK_CALLBACK_URL']?.trim() ?? '');
  }

  static String get backendUrl => _backendUrl;
}
