import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  /// Default timeout for backend HTTP calls (auth refresh, profile, etc.).
  static const Duration networkTimeout = Duration(seconds: 10);

  /// LLM / start-dialog calls often need longer than a normal REST read.
  static const Duration agentTimeout = Duration(seconds: 90);

  static late String _backendUrl;
  static late String paystackPublicKey;
  static late String paystackCallbackUrl;
  static late String privacyPolicyUrl;
  static late String termsOfServiceUrl;
  static late String homeYoutubeUrl;
  static const String publicWebsiteUrl = 'https://useautobus.com';
  static const String publicWebsiteLoginUrl = '$publicWebsiteUrl/login';

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

    const definePrivacyPolicyUrl = String.fromEnvironment('PRIVACY_POLICY_URL');
    privacyPolicyUrl = definePrivacyPolicyUrl.isNotEmpty
        ? definePrivacyPolicyUrl
        : (envLoaded
            ? (dotenv.env['PRIVACY_POLICY_URL']?.trim() ??
                'https://useautobus.com/privacy')
            : 'https://useautobus.com/privacy');

    const defineTermsOfServiceUrl =
        String.fromEnvironment('TERMS_OF_SERVICE_URL');
    termsOfServiceUrl = defineTermsOfServiceUrl.isNotEmpty
        ? defineTermsOfServiceUrl
        : (envLoaded
            ? (dotenv.env['TERMS_OF_SERVICE_URL']?.trim() ??
                'https://useautobus.com/terms')
            : 'https://useautobus.com/terms');

    const defineHomeYoutubeUrl = String.fromEnvironment('HOME_YOUTUBE_URL');
    homeYoutubeUrl = defineHomeYoutubeUrl.isNotEmpty
        ? defineHomeYoutubeUrl.trim()
        : (envLoaded ? (dotenv.env['HOME_YOUTUBE_URL'] ?? '').trim() : '');
  }

  static String get backendUrl => _backendUrl;
}
