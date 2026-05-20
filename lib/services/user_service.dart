import 'package:supabase_flutter/supabase_flutter.dart';

class UserService {
  final _client = Supabase.instance.client;

  Future<void> createUserAfterSignUp({
    required String userId,
    required String email,
    required String passwordHash,
  }) async {
    await _client.from('users').insert({
      'user_id': userId,
      'email': email,
      'password_hash': passwordHash,
    });

    await _client.from('user_profile').insert({
      'user_id': userId,
      'name': null,
      'birth_date': null,
      'gender': null,
    });

    final topicsResponse = await _client
        .from('topics')
        .select('topic_id')
        .order('topic_id');

    final topics = List<Map<String, dynamic>>.from(topicsResponse);

    if (topics.isNotEmpty) {
      final preferenceRows = topics.map((topic) {
        return {
          'user_id': userId,
          'topic_id': topic['topic_id'],
        };
      }).toList();

      await _client.from('user_preferences').insert(preferenceRows);
    }
  }

  Future<Map<String, dynamic>?> getCurrentUserProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    final response = await _client
        .from('user_profile')
        .select()
        .eq('user_id', user.id)
        .maybeSingle();

    return response;
  }
}