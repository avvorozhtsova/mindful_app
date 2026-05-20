import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../app/theme.dart';
import '../../services/content_service.dart';
import '../../services/settings_service.dart';

class MaterialScreen extends StatefulWidget {
  final int contentId;

  const MaterialScreen({
    super.key,
    required this.contentId,
  });

  @override
  State<MaterialScreen> createState() => _MaterialScreenState();
}

class _MaterialScreenState extends State<MaterialScreen> {
  final _contentService = ContentService();
  final _settingsService = SettingsService();
  final ScrollController _scrollController = ScrollController();

  bool _isLoading = true;
  bool _isFavorite = false;
  bool _isGuest = false;
  bool _completionSent = false;
  bool _reachedBottom = false;

  Map<String, dynamic>? _material;

  Timer? _completionTimer;

  @override
  void initState() {
    super.initState();
    _loadMaterial();
    _scrollController.addListener(_handleScroll);

    _completionTimer = Timer(const Duration(seconds: 20), () {
      _tryCompleteByTime();
    });
  }

  void _handleScroll() {
    if (_completionSent || _isGuest || !_scrollController.hasClients) return;

    final position = _scrollController.position;

    if (!position.hasContentDimensions) return;

    // Если статья короткая и почти не скроллится
    if (position.maxScrollExtent <= 40) {
      return;
    }

    final progress = position.pixels / position.maxScrollExtent;

    if (progress >= 0.9) {
      _reachedBottom = true;
      _markCompleted();
    }
  }

  Future<void> _tryCompleteByTime() async {
    if (_completionSent || _isGuest) return;

    if (!_scrollController.hasClients) {
      await _markCompleted();
      return;
    }

    final position = _scrollController.position;

    // Если статья короткая и почти целиком помещается на экран,
    // считаем её прочитанной после 20 секунд.
    if (position.maxScrollExtent <= 40) {
      await _markCompleted();
    }
  }

  Future<void> _markCompleted() async {
    if (_completionSent || _isGuest) return;

    _completionSent = true;
    await _contentService.markAsCompleted(widget.contentId);
  }

  Future<void> _loadMaterial() async {
    try {
      final isGuest = await _settingsService.getIsGuest();
      final material = await _contentService.getContentById(widget.contentId);

      if (!mounted) return;

      if (material == null) {
        setState(() {
          _material = null;
          _isLoading = false;
        });
        return;
      }

      bool isFavorite = false;

      if (!isGuest) {
        try {
          await _contentService.addToHistory(widget.contentId);
        } catch (_) {}

        try {
          isFavorite = await _contentService.isFavorite(widget.contentId);
        } catch (_) {}
      }

      if (!mounted) return;

      setState(() {
        _isGuest = isGuest;
        _material = material;
        _isFavorite = isFavorite;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _material = null;
      });
    }
  }

  Future<void> _toggleFavorite() async {
    if (_isFavorite) {
      await _contentService.removeFromFavorites(widget.contentId);
    } else {
      await _contentService.addToFavorites(widget.contentId);
    }

    if (!mounted) return;

    setState(() {
      _isFavorite = !_isFavorite;
    });
  }

  Future<void> _openOriginalLink() async {
    final url = _material?['url'] as String?;
    if (url == null || url.isEmpty) return;

    final uri = Uri.tryParse(url);
    if (uri == null) return;

    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  void dispose() {
    _completionTimer?.cancel();
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Материал'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _material == null
              ? const Center(child: Text('Материал не найден'))
              : Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Expanded(
                        child: Scrollbar(
                          thumbVisibility: true,
                          controller: _scrollController,
                          child: SingleChildScrollView(
                            controller: _scrollController,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(0, 0, 12, 0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _material!['title'] as String,
                                    style: textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _material!['text'] as String,
                                    style: textTheme.bodyLarge,
                                  ),
                                  const SizedBox(height: 24),
                                  const Divider(),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Источник: ${_material!['source_name'] ?? ''}',
                                    style: textTheme.bodyMedium,
                                  ),
                                  const SizedBox(height: 8),
                                  GestureDetector(
                                    onTap: _openOriginalLink,
                                    child: Text(
                                      (_material!['url'] as String?) ?? '',
                                      style: textTheme.bodyMedium?.copyWith(
                                        decoration: TextDecoration.underline,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (!_isGuest)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _toggleFavorite,
                            icon: Icon(
                              _isFavorite ? Icons.favorite : Icons.favorite_border,
                              color: Colors.white,
                            ),
                            label: Text(
                              _isFavorite
                                  ? 'Убрать из избранного'
                                  : 'В избранное',
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }
}