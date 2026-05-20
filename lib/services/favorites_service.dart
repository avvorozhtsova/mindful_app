import 'package:supabase_flutter/supabase_flutter.dart';

class FavoritesService {
  final _client = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getMyFavorites() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];

    final response = await _client
        .from('user_favorites')
        .select(
          'content_id, saved_at, content!inner('
          'content_id, title, text, url, published_at, source_id, '
          'sources(name)'
          ')',
        )
        .eq('user_id', user.id)
        .order('saved_at', ascending: false);

    final rows = List<Map<String, dynamic>>.from(response);
    final result = <Map<String, dynamic>>[];

    for (final row in rows) {
      final content = Map<String, dynamic>.from(row['content']);
      final source = content['sources'] != null
          ? Map<String, dynamic>.from(content['sources'])
          : <String, dynamic>{};

      String topicName = 'Без темы';

      final topicResponse = await _client
          .from('content_topics')
          .select('topics!inner(name)')
          .eq('content_id', content['content_id'])
          .limit(1)
          .maybeSingle();

      if (topicResponse != null && topicResponse['topics'] != null) {
        final topic = Map<String, dynamic>.from(topicResponse['topics']);
        topicName = topic['name'] ?? 'Без темы';
      }

      result.add({
        'content_id': content['content_id'],
        'title': content['title'] ?? '',
        'text': content['text'] ?? '',
        'url': content['url'] ?? '',
        'published_at': content['published_at'],
        'saved_at': row['saved_at'],
        'source_name': source['name'] ?? '',
        'topic_name': topicName,
      });
    }

    return result;
  }
}