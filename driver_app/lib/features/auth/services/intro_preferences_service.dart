import 'package:shared_preferences/shared_preferences.dart';

class IntroPreferencesService {
  static const String hidePromoSlidesKey = 'hide_promo_slides';
  static const String introCompletedCountKey = 'intro_completed_count';

  static const String driverIntroHiddenKey = 'delivery_driver_intro_hidden';
  static const String businessIntroHiddenKey = 'business_partner_intro_hidden';
  static const String driverIntroCompletedCountKey =
      'delivery_driver_intro_completed_count';
  static const String businessIntroCompletedCountKey =
      'business_partner_intro_completed_count';

  final SharedPreferencesAsync _prefs = SharedPreferencesAsync();

  Future<bool> shouldHidePromoSlides([String? customKey]) async {
    final String key = _resolveKey(customKey, hidePromoSlidesKey);
    return await _prefs.getBool(key) ?? false;
  }

  Future<void> setHidePromoSlides(dynamic keyOrValue, [bool? value]) async {
    if (keyOrValue is String) {
      await _prefs.setBool(_resolveKey(keyOrValue, hidePromoSlidesKey), value ?? false);
      return;
    }

    final bool resolvedValue = keyOrValue is bool ? keyOrValue : (value ?? false);
    await _prefs.setBool(hidePromoSlidesKey, resolvedValue);
  }

  Future<int> getIntroCompletedCount([String? customKey]) async {
    final String key = _resolveKey(customKey, introCompletedCountKey);
    return await _prefs.getInt(key) ?? 0;
  }

  Future<void> incrementIntroCompletedCount([String? customKey]) async {
    final String key = _resolveKey(customKey, introCompletedCountKey);
    final int current = await getIntroCompletedCount(key);
    await _prefs.setInt(key, current + 1);
  }

  Future<void> clearHidePromoSlides([String? customKey]) async {
    await _prefs.remove(_resolveKey(customKey, hidePromoSlidesKey));
  }

  Future<void> clearIntroCompletedCount([String? customKey]) async {
    await _prefs.remove(_resolveKey(customKey, introCompletedCountKey));
  }

  Future<void> clearDriverIntroState() async {
    await clearHidePromoSlides(driverIntroHiddenKey);
    await clearIntroCompletedCount(driverIntroCompletedCountKey);
  }

  Future<void> clearBusinessIntroState() async {
    await clearHidePromoSlides(businessIntroHiddenKey);
    await clearIntroCompletedCount(businessIntroCompletedCountKey);
  }

  String _resolveKey(String? customKey, String fallback) {
    final String normalized = customKey?.trim() ?? '';
    return normalized.isEmpty ? fallback : normalized;
  }
}
