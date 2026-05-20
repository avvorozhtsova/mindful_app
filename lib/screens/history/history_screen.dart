import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../app/theme.dart';
import '../topic/material_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _client = Supabase.instance.client;

  bool _isLoading = true;
  List<Map<String, dynamic>> _historyItems = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return;

      final response = await _client
          .from('user_history')
          .select(
            'viewed_at, content!inner(content_id, title, text, url, sources(name))',
          )
          .eq('user_id', user.id)
          .order('viewed_at', ascending: false);

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
          'source_name': source['name'] ?? '',
          'viewed_at': row['viewed_at'],
        };
      }).toList();

      if (!mounted) return;

      setState(() {
        _historyItems = mapped;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _makeSummary(String text) {
    final cleaned = text.replaceAll('\n', ' ').trim();
    if (cleaned.length <= 180) return cleaned;
    return '${cleaned.substring(0, 180)}...';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('История просмотров'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _historyItems.isEmpty
                ? const Center(child: Text('История пока пустая'))
                : ListView.builder(
                    itemCount: _historyItems.length,
                    itemBuilder: (context, index) {
                      final item = _historyItems[index];

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => MaterialScreen(
                                  contentId: item['content_id'] as int,
                                ),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(16, 16, 24, 16),
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.primary),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['title'] as String,
                                  style: textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  _makeSummary(item['text'] as String),
                                  style: textTheme.bodyMedium,
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Источник: ${item['source_name']}',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}