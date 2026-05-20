import 'dart:math';
import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../services/topic_service.dart';
import '../../services/settings_service.dart';
import '../topic/topic_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _topicService = TopicService();
  final _settingsService = SettingsService();

  bool _isLoading = true;
  bool _isGuest = false;
  List<Map<String, dynamic>> _allTopics = [];
  List<Map<String, dynamic>> _visibleTopics = [];

  @override
  void initState() {
    super.initState();
    _loadTopics();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowOnboarding();
    });
  }

  Future<void> _loadTopics() async {
    try {
      final isGuest = await _settingsService.getIsGuest();
      final topics = await _topicService.getAvailableTopics();

      if (!mounted) return;

      setState(() {
        _isGuest = isGuest;
        _allTopics = topics;
        _visibleTopics = _pickRandomTopics(topics, 4);
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _checkAndShowOnboarding() async {
    final hasSeen = await _settingsService.getHasSeenOnboarding();
    final isGuest = await _settingsService.getIsGuest();

    if (!mounted || hasSeen || isGuest) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          backgroundColor: AppColors.background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: AppColors.primary),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(
                  child: Text(
                    'Добро пожаловать!',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Здесь ты можешь:',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  '• менять любимые темы в настройках;\n'
                  '• заполнять профиль;\n'
                  '• сохранять материалы в избранное;\n'
                  '• отслеживать свой прогресс и историю просмотров.',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Начать можно с выбора интересной темы на главном экране.',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 18),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text(
                      'Понятно',
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
      },
    );

    await _settingsService.setHasSeenOnboarding(true);
  }

  List<Map<String, dynamic>> _pickRandomTopics(
    List<Map<String, dynamic>> source,
    int count,
  ) {
    final shuffled = List<Map<String, dynamic>>.from(source);
    shuffled.shuffle(Random());
    return shuffled.take(count).toList();
  }

  void _regenerateTopics() {
    setState(() {
      _visibleTopics = _pickRandomTopics(_allTopics, 4);
    });
  }

  void _showGuestMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        leading: _isGuest
            ? BackButton(
                onPressed: () async {
                  await _settingsService.setIsGuest(false);
                  if (!mounted) return;
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/sign-in',
                    (route) => false,
                  );
                },
              )
            : null,
        title: const Text('Главная'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () {
              if (_isGuest) {
                _showGuestMessage('Избранное доступно только после регистрации');
                return;
              }
              Navigator.pushNamed(context, '/favorites');
            },
            icon: const Icon(Icons.favorite_border),
          ),
          IconButton(
            onPressed: () {
              if (_isGuest) {
                _showGuestMessage('Профиль доступен только после регистрации');
                return;
              }
              Navigator.pushNamed(context, '/profile');
            },
            icon: const Icon(Icons.person_outline),
          ),
          IconButton(
            onPressed: () async {
              if (_isGuest) {
                _showGuestMessage('Настройки доступны только после регистрации');
                return;
              }
              await Navigator.pushNamed(context, '/settings');
              await _loadTopics();
            },
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 18),
                    Text(
                      'Что хочешь изучить сегодня?',
                      textAlign: TextAlign.center,
                      style: textTheme.titleLarge?.copyWith(
                        color: AppColors.primary,
                        fontSize: 22,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 32),
                    for (final topic in _visibleTopics)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: SizedBox(
                          height: 54,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: AppColors.background,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              textStyle: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => TopicScreen(
                                    topicId: topic['topic_id'] as int,
                                    topicName: topic['name'] as String,
                                  ),
                                ),
                              );
                            },
                            child: Text(topic['name'] as String),
                          ),
                        ),
                      ),
                    const SizedBox(height: 6),
                    Center(
                      child: TextButton(
                        onPressed: _regenerateTopics,
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          textStyle: textTheme.bodyMedium?.copyWith(
                            decoration: TextDecoration.underline,
                          ),
                        ),
                        child: const Text('Другое ↻'),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}