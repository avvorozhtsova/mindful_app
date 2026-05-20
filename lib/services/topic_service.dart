import 'package:supabase_flutter/supabase_flutter.dart';
import 'settings_service.dart';

class TopicService {
  final _client = Supabase.instance.client;
  final _settingsService = SettingsService();

  Future<List<Map<String, dynamic>>> getAvailableTopics() async {
    final isGuest = await _settingsService.getIsGuest();
    final user = _client.auth.currentUser;

    if (isGuest || user == null) {
      final response = await _client
          .from('topics')
          .select('topic_id, name')
          .order('topic_id');

      return List<Map<String, dynamic>>.from(response);
    }

    final response = await _client
        .from('user_preferences')
        .select('topic_id, topics!inner(topic_id, name)')
        .eq('user_id', user.id);

    final rows = List<Map<String, dynamic>>.from(response);

    return rows.map((row) {
      final topic = Map<String, dynamic>.from(row['topics']);
      return {
        'topic_id': topic['topic_id'],
        'name': topic['name'],
      };
    }).toList();
  }
}