import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileService {
  final _client = Supabase.instance.client;

  Future<Map<String, dynamic>?> getMyProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    final response = await _client
        .from('user_profile')
        .select()
        .eq('user_id', user.id)
        .maybeSingle();

    return response == null ? null : Map<String, dynamic>.from(response);
  }

  Future<void> updateProfile({
    required String name,
    String? gender,
    String? birthDate,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    await _client.from('user_profile').upsert({
      'user_id': user.id,
      'name': name,
      'gender': gender,
      'birth_date': birthDate,
    });
  }
}