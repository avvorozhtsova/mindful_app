import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../services/favorites_service.dart';
import '../topic/material_screen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final _favoritesService = FavoritesService();

  bool _isLoading = true;
  List<Map<String, dynamic>> _favorites = [];
  final Map<String, bool> _expandedTopics = {};

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final favorites = await _favoritesService.getMyFavorites();

    if (!mounted) return;

    setState(() {
      _favorites = favorites;
      for (final item in favorites) {
        final topic = item['topic_name'] as String;
        _expandedTopics.putIfAbsent(topic, () => false);
      }
      _isLoading = false;
    });
  }

  String _makeSummary(String text) {
    final cleaned = text.replaceAll('\n', ' ').trim();
    if (cleaned.length <= 140) return cleaned;
    return '${cleaned.substring(0, 140)}...';
  }

  Map<String, List<Map<String, dynamic>>> _groupByTopic() {
    final grouped = <String, List<Map<String, dynamic>>>{};

    for (final item in _favorites) {
      final topic = item['topic_name'] as String;
      grouped.putIfAbsent(topic, () => []);
      grouped[topic]!.add(item);
    }

    return grouped;
  }

  Widget _buildCard(Map<String, dynamic> item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
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
          padding: const EdgeInsets.fromLTRB(14, 14, 18, 14),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.primary),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item['title'] as String,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _makeSummary(item['text'] as String),
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Источник: ${item['source_name']}',
                style: TextStyle(
                  color: AppColors.primary.withOpacity(0.85),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopicBlock(String topic, List<Map<String, dynamic>> items) {
    final isExpanded = _expandedTopics[topic] ?? false;
    final previewItems = items.take(1).toList();
    final visibleItems = isExpanded ? items : previewItems;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.primary),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                setState(() {
                  _expandedTopics[topic] = !isExpanded;
                });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        topic,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      '${items.length}',
                      style: TextStyle(
                        color: AppColors.primary.withOpacity(0.8),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            ...visibleItems.map(_buildCard),
            if (!isExpanded && items.length > 3)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    setState(() {
                      _expandedTopics[topic] = true;
                    });
                  },
                  child: const Text(
                    'Показать всё',
                    style: TextStyle(
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _groupByTopic();
    final sortedTopics = grouped.keys.toList()..sort();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Избранное'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _favorites.isEmpty
                ? const Center(child: Text('Тут пока пусто'))
                : ListView(
                    children: sortedTopics
                        .map((topic) => _buildTopicBlock(topic, grouped[topic]!))
                        .toList(),
                  ),
      ),
    );
  }
}