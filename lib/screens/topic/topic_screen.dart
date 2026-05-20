import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../services/content_service.dart';
import 'material_screen.dart';

class TopicScreen extends StatefulWidget {
  final int topicId;
  final String topicName;

  const TopicScreen({
    super.key,
    required this.topicId,
    required this.topicName,
  });

  @override
  State<TopicScreen> createState() => _TopicScreenState();
}

class _TopicScreenState extends State<TopicScreen> {
  final _contentService = ContentService();

  bool _isLoading = true;
  List<Map<String, dynamic>> _materials = [];

  @override
  void initState() {
    super.initState();
    _loadMaterials();
  }

  Future<void> _loadMaterials() async {
    try {
      final materials = await _contentService.getContentByTopic(widget.topicId);

      setState(() {
        _materials = materials;
        _isLoading = false;
      });
    } catch (e) {
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
        title: Text(widget.topicName),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _materials.isEmpty
                ? const Center(child: Text('Материалы по этой теме пока не найдены'))
                : ListView.builder(
                    itemCount: _materials.length,
                    itemBuilder: (context, index) {
                      final item = _materials[index];

                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 24, 16),
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
                            padding: const EdgeInsets.all(16),
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