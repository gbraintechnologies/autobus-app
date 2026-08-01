import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static late String _backendUrl;
  static late String paystackPublicKey;
  static late String paystackCallbackUrl;

  static Future<void> init() async {
    bool envLoaded = true;
    try {
      await dotenv.load(fileName: '.env');
    } catch (e) {
      envLoaded = false;
      debugPrint('AppConfig: .env not loaded ($e); using dart-define/defaults');
    }

    const defineBackendUrl = String.fromEnvironment('BACKEND_URL');
    final envBackendUrl = envLoaded ? dotenv.env['BACKEND_URL']?.trim() : null;
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
        : (envLoaded ? (dotenv.env['PAYSTACK_PUBLIC_KEY']?.trim() ?? '') : '');

    const definePaystackCallback =
        String.fromEnvironment('PAYSTACK_CALLBACK_URL');
    paystackCallbackUrl = definePaystackCallback.isNotEmpty
        ? definePaystackCallback
        : (envLoaded
            ? (dotenv.env['PAYSTACK_CALLBACK_URL']?.trim() ?? '')
            : '');
  }

  static String get backendUrl => _backendUrl;
}
