import 'package:shared_preferences/shared_preferences.dart';

class IntroPreferencesService {
  static const String _legacyHidePromoSlidesKey = 'hide_promo_slides';
  static const String deliveryDriverIntroHiddenKey =
      'delivery_driver_intro_hidden';
  static const String businessPartnerIntroHiddenKey =
      'business_partner_intro_hidden';

  Future<bool> shouldHidePromoSlides([String? key]) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    if (key != null && key.trim().isNotEmpty) {
      return prefs.getBool(key.trim()) ?? false;
    }

    return prefs.getBool(_legacyHidePromoSlidesKey) ?? false;
  }

  Future<void> setHidePromoSlides(dynamic arg1, [bool? arg2]) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    if (arg1 is String) {
      final String key = arg1.trim();
      final bool value = arg2 ?? true;

      if (key.isEmpty) {
        throw ArgumentError('Preference key cannot be empty.');
      }

      await prefs.setBool(key, value);
      return;
    }

    if (arg1 is bool) {
      await prefs.setBool(_legacyHidePromoSlidesKey, arg1);
      return;
    }

    throw ArgumentError(
      'setHidePromoSlides expects either (bool value) or (String key, bool value).',
    );
  }

  Future<bool> shouldHideDeliveryDriverIntro() {
    return shouldHidePromoSlides(deliveryDriverIntroHiddenKey);
  }

  Future<bool> shouldHideBusinessPartnerIntro() {
    return shouldHidePromoSlides(businessPartnerIntroHiddenKey);
  }

  Future<void> setHideDeliveryDriverIntro(bool value) {
    return setHidePromoSlides(deliveryDriverIntroHiddenKey, value);
  }

  Future<void> setHideBusinessPartnerIntro(bool value) {
    return setHidePromoSlides(businessPartnerIntroHiddenKey, value);
  }

  Future<void> resetDeliveryDriverIntro() {
    return setHideDeliveryDriverIntro(false);
  }

  Future<void> resetBusinessPartnerIntro() {
    return setHideBusinessPartnerIntro(false);
  }

  Future<void> resetAllIntroPreferences() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_legacyHidePromoSlidesKey);
    await prefs.remove(deliveryDriverIntroHiddenKey);
    await prefs.remove(businessPartnerIntroHiddenKey);
  }
}
