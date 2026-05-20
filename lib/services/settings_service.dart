import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const _notificationsKey = 'daily_notifications';
  static const _notificationTimeKey = 'notification_time';
  static const _languageKey = 'app_language';
  static const _isGuestKey = 'is_guest';
  static const _hasSeenOnboardingKey = 'has_seen_onboarding';

  Future<bool> getDailyNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_notificationsKey) ?? false;
  }

  Future<void> setDailyNotifications(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationsKey, value);
  }

  Future<String> getNotificationTime() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_notificationTimeKey) ?? '09:41';
  }

  Future<void> setNotificationTime(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_notificationTimeKey, value);
  }

  Future<String> getLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_languageKey) ?? 'ru';
  }

  Future<void> setLanguage(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, value);
  }

  Future<bool> getIsGuest() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isGuestKey) ?? false;
  }

  Future<void> setIsGuest(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isGuestKey, value);
  }

  Future<bool> getHasSeenOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_hasSeenOnboardingKey) ?? false;
  }

  Future<void> setHasSeenOnboarding(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasSeenOnboardingKey, value);
  }
}