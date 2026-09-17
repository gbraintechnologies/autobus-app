import 'package:flutter/foundation.dart';

/// App Store Connect consumable product IDs (iOS / iPadOS).
///
/// Android and web buy the same packs with Paystack.
/// iOS product IDs:
///   autobus.credits.20.v4
///   autobus.credits.50.v4
///   autobus.credits.150.v5
///   autobus.credits.400.v4
class AppleIapIds {
  static const String prefix = 'autobus';
  static const String androidPackageName = 'com.autobus.app';

  static const String credits20 = 'autobus.credits.20.v4';
  static const String credits50 = 'autobus.credits.50.v4';
  static const String credits150 = 'autobus.credits.150.v5';
  static const String credits400 = 'autobus.credits.400.v4';

  static String slug(String name) {
    return name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  static Map<String, String> forPlanName(String name) {
    final s = slug(name);
    return {
      'monthly': '$prefix.$s.monthly',
      'annual': '$prefix.$s.yearly',
    };
  }

  static const Set<String> creditProductIds = {
    credits20,
    credits50,
    credits150,
    credits400,
  };

  /// Apple In-App Purchase only. Android always uses Paystack.
  static bool get usesAppleIap {
    if (kIsWeb) return false;
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return true;
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        return false;
    }
  }

  static bool get isSupported => usesAppleIap;

  static bool get isIosApp {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.iOS;
  }

  static bool get isAndroidApp {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android;
  }
}
