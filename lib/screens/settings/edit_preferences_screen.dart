import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../app/theme.dart';

class EditPreferencesScreen extends StatefulWidget {
  const EditPreferencesScreen({super.key});

  @override
  State<EditPreferencesScreen> createState() => _EditPreferencesScreenState();
}

class _EditPreferencesScreenState extends State<EditPreferencesScreen> {
  final _client = Supabase.instance.client;

  bool _isLoading = true;
  bool _isSaving = false;

  List<Map<String, dynamic>> _topics = [];
  Set<int> _selectedTopicIds = {};

  @override
  void initState() {
    super.initState();
    _loadTopicsAndPreferences();
  }

  Future<void> _loadTopicsAndPreferences() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return;

      final topicsResponse = await _client
          .from('topics')
          .select('topic_id, name')
          .order('topic_id');

      final prefsResponse = await _client
          .from('user_preferences')
          .select('topic_id')
          .eq('user_id', user.id);

      final topics = List<Map<String, dynamic>>.from(topicsResponse);
      final prefs = List<Map<String, dynamic>>.from(prefsResponse);

      final selected = prefs
          .map((e) => e['topic_id'] as int)
          .toSet();

      if (!mounted) return;

      setState(() {
        _topics = topics;
        _selectedTopicIds = selected;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _toggleTopic(int topicId) {
    setState(() {
      if (_selectedTopicIds.contains(topicId)) {
        _selectedTopicIds.remove(topicId);
      } else {
        _selectedTopicIds.add(topicId);
      }
    });
  }

  Future<void> _savePreferences() async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    
    if (_selectedTopicIds.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Нужно выбрать минимум 4 темы'),
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await _client
          .from('user_preferences')
          .delete()
          .eq('user_id', user.id);

      if (_selectedTopicIds.isNotEmpty) {
        final rows = _selectedTopicIds
            .map((topicId) => {
                  'user_id': user.id,
                  'topic_id': topicId,
                })
            .toList();

        await _client.from('user_preferences').insert(rows);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Предпочтения сохранены')),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка сохранения: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textColor = AppColors.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройки'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.primary),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Выберите свои любимые темы',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _topics.length,
                        itemBuilder: (context, index) {
                          final topic = _topics[index];
                          final topicId = topic['topic_id'] as int;
                          final isChecked = _selectedTopicIds.contains(topicId);

                          return InkWell(
                            onTap: () => _toggleTopic(topicId),
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: Checkbox(
                                      value: isChecked,
                                      activeColor: AppColors.primary,
                                      checkColor: AppColors.background,
                                      side: const BorderSide(
                                        color: AppColors.primary,
                                        width: 1.5,
                                      ),
                                      onChanged: (_) => _toggleTopic(topicId),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      topic['name'].toString(),
                                      style: TextStyle(
                                        color: textColor,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _isSaving ? null : _savePreferences,
                        child: _isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text(
                                'Готово',
                                style: TextStyle(
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}