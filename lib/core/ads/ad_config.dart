import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AdConfig {
  const AdConfig._();

  static bool get supportsAds {
    return !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
  }

  static String? get bannerAdUnitId {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return _envValue('ADMOB_ANDROID_BANNER_AD_UNIT_ID');
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return _envValue('ADMOB_IOS_BANNER_AD_UNIT_ID');
    }
    return null;
  }

  static String? _envValue(String key) {
    if (!dotenv.isInitialized) return null;

    final value = dotenv.maybeGet(key)?.trim();
    return value == null || value.isEmpty ? null : value;
  }
}
