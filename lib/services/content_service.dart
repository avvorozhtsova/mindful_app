import 'package:supabase_flutter/supabase_flutter.dart';

class ContentService {
  final _client = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getContentByTopic(int topicId) async {
    final response = await _client
        .from('content_topics')
        .select(
          'content_id, content!inner('
          'content_id, title, text, url, published_at, source_id, '
          'sources!inner(name, base_url, rss_url)'
          ')',
        )
        .eq('topic_id', topicId);

    final rows = List<Map<String, dynamic>>.from(response);

    final mapped = rows.map((row) {
      final content = Map<String, dynamic>.from(row['content']);
      final source = content['sources'] != null
          ? Map<String, dynamic>.from(content['sources'])
          : <String, dynamic>{};

      return {
        'content_id': content['content_id'],
        'title': content['title'] ?? '',
        'text': content['text'] ?? '',
        'url': content['url'] ?? '',
        'published_at': content['published_at'],
        'source_name': source['name'] ?? '',
        'source_base_url': source['base_url'] ?? '',
        'source_rss_url': source['rss_url'] ?? '',
      };
    }).toList();

    return mapped.take(7).toList();
  }

  Future<Map<String, dynamic>?> getContentById(int contentId) async {
    final response = await _client
        .from('content')
        .select('content_id, title, text, url, published_at, source_id')
        .eq('content_id', contentId)
        .maybeSingle();

    if (response == null) return null;

    final content = Map<String, dynamic>.from(response);

    String sourceName = '';
    String sourceBaseUrl = '';
    String sourceRssUrl = '';

    final sourceId = content['source_id'];
    if (sourceId != null) {
      final sourceResponse = await _client
          .from('sources')
          .select('name, base_url, rss_url')
          .eq('source_id', sourceId)
          .maybeSingle();

      if (sourceResponse != null) {
        final source = Map<String, dynamic>.from(sourceResponse);
        sourceName = source['name'] ?? '';
        sourceBaseUrl = source['base_url'] ?? '';
        sourceRssUrl = source['rss_url'] ?? '';
      }
    }

    return {
      'content_id': content['content_id'],
      'title': content['title'] ?? '',
      'text': content['text'] ?? '',
      'url': content['url'] ?? '',
      'published_at': content['published_at'],
      'source_name': sourceName,
      'source_base_url': sourceBaseUrl,
      'source_rss_url': sourceRssUrl,
    };
  }

  Future<void> addToHistory(int contentId) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    final existing = await _client
        .from('user_history')
        .select('user_id, content_id, completed_at')
        .eq('user_id', user.id)
        .eq('content_id', contentId)
        .maybeSingle();

    if (existing != null) return;

    await _client.from('user_history').insert({
      'user_id': user.id,
      'content_id': contentId,
      'viewed_at': DateTime.now().toIso8601String(),
      'completed_at': null,
    });
  }

  Future<void> markAsCompleted(int contentId) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    final existing = await _client
        .from('user_history')
        .select('user_id, content_id, completed_at')
        .eq('user_id', user.id)
        .eq('content_id', contentId)
        .maybeSingle();

    if (existing == null) {
      await _client.from('user_history').insert({
        'user_id': user.id,
        'content_id': contentId,
        'viewed_at': DateTime.now().toIso8601String(),
        'completed_at': DateTime.now().toIso8601String(),
      });
      return;
    }

    if (existing['completed_at'] != null) return;

    await _client
        .from('user_history')
        .update({
          'completed_at': DateTime.now().toIso8601String(),
        })
        .eq('user_id', user.id)
        .eq('content_id', contentId);
  }

  Future<bool> isFavorite(int contentId) async {
    final user = _client.auth.currentUser;
    if (user == null) return false;

    final response = await _client
        .from('user_favorites')
        .select('content_id')
        .eq('user_id', user.id)
        .eq('content_id', contentId)
        .maybeSingle();

    return response != null;
  }

  Future<void> addToFavorites(int contentId) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    final existing = await _client
        .from('user_favorites')
        .select('content_id')
        .eq('user_id', user.id)
        .eq('content_id', contentId)
        .maybeSingle();

    if (existing != null) return;

    await _client.from('user_favorites').insert({
      'user_id': user.id,
      'content_id': contentId,
      'saved_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> removeFromFavorites(int contentId) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    await _client
        .from('user_favorites')
        .delete()
        .eq('user_id', user.id)
        .eq('content_id', contentId);
  }
}