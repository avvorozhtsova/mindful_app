import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'user_service.dart';
import 'settings_service.dart';

class AuthService {
  final _client = Supabase.instance.client;
  final _settingsService = SettingsService();

  User? get currentUser => _client.auth.currentUser;

  String hashPassword(String password) {
    return sha256.convert(utf8.encode(password)).toString();
  }

  Future<void> signUp({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
    );

    final user = response.user;
    if (user == null) {
      throw Exception('Не удалось создать пользователя');
    }

    final passwordHash = hashPassword(password);

    await UserService().createUserAfterSignUp(
      userId: user.id,
      email: email,
      passwordHash: passwordHash,
    );

    await _settingsService.setIsGuest(false);
    await _settingsService.setHasSeenOnboarding(false);
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );

    await _settingsService.setIsGuest(false);
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
    await _settingsService.setIsGuest(false);
  }
}