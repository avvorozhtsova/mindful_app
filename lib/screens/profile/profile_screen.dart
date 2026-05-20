import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../app/theme.dart';
import '../../services/auth_service.dart';
import '../../services/profile_service.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _profileService = ProfileService();
  final _authService = AuthService();
  final _client = Supabase.instance.client;

  bool _isLoading = true;
  Map<String, dynamic>? _profile;

  Set<String> _activityDays = {};
  List<String> _interestLabels = [];
  List<double> _interestValues = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final profile = await _profileService.getMyProfile();
      final activityDays = await _loadActivityDays();
      final interestData = await _loadInterestData();

      if (!mounted) return;

      setState(() {
        _profile = profile;
        _activityDays = activityDays;
        _interestLabels = interestData.keys.toList();
        _interestValues = interestData.values.toList();
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<Set<String>> _loadActivityDays() async {
    final user = _client.auth.currentUser;
    if (user == null) return {};

    final response = await _client
        .from('user_history')
        .select('completed_at')
        .eq('user_id', user.id)
        .not('completed_at', 'is', null);

    final rows = List<Map<String, dynamic>>.from(response);

    return rows.map((row) {
      final dt = DateTime.parse(row['completed_at'].toString()).toLocal();
      return _dateKey(DateTime(dt.year, dt.month, dt.day));
    }).toSet();
  }

  Future<Map<String, double>> _loadInterestData() async {
    final user = _client.auth.currentUser;
    if (user == null) return {};

    final topicsResponse = await _client
        .from('topics')
        .select('topic_id, name')
        .order('topic_id');

    final allTopics = List<Map<String, dynamic>>.from(topicsResponse);

    final historyResponse = await _client
        .from('user_history')
        .select('content_id')
        .eq('user_id', user.id)
        .not('completed_at', 'is', null);

    final historyRows = List<Map<String, dynamic>>.from(historyResponse);
    final contentIds = historyRows
        .map((e) => e['content_id'])
        .where((e) => e != null)
        .toSet()
        .toList();

    final counts = <int, int>{};

    if (contentIds.isNotEmpty) {
      final contentTopicsResponse = await _client
          .from('content_topics')
          .select('content_id, topic_id')
          .inFilter('content_id', contentIds);

      final contentTopics = List<Map<String, dynamic>>.from(contentTopicsResponse);

      for (final row in contentTopics) {
        final topicId = row['topic_id'] as int;
        counts[topicId] = (counts[topicId] ?? 0) + 1;
      }
    }

    final maxCount = counts.values.isEmpty ? 1 : counts.values.reduce(max);
    final result = <String, double>{};

    for (final topic in allTopics) {
      final topicId = topic['topic_id'] as int;
      final name = topic['name'] as String;
      final count = counts[topicId] ?? 0;
      final value = count == 0 ? 8.0 : (count / maxCount) * 100;
      result[name] = value;
    }

    return result;
  }

  String _dateKey(DateTime date) {
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '${date.year}-$m-$d';
  }

  int _calculateAge(dynamic birthDateValue) {
    if (birthDateValue == null) return 0;

    final birthDate = DateTime.tryParse(birthDateValue.toString());
    if (birthDate == null) return 0;

    final now = DateTime.now();
    int age = now.year - birthDate.year;

    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }

    return age;
  }

  int _calculateStreak() {
    int streak = 0;
    DateTime current = DateTime.now();
    current = DateTime(current.year, current.month, current.day);

    while (_activityDays.contains(_dateKey(current))) {
      streak++;
      current = current.subtract(const Duration(days: 1));
    }

    return streak;
  }

  String _monthNameRu(int month) {
    const months = [
      '',
      'Январь',
      'Февраль',
      'Март',
      'Апрель',
      'Май',
      'Июнь',
      'Июль',
      'Август',
      'Сентябрь',
      'Октябрь',
      'Ноябрь',
      'Декабрь',
    ];
    return months[month];
  }

  Future<void> _signOut() async {
    await _authService.signOut();

    if (!mounted) return;

    Navigator.pushNamedAndRemoveUntil(
      context,
      '/sign-in',
      (route) => false,
    );
  }

  Widget _buildCalendar() {
    final now = DateTime.now();
    final year = now.year;
    final month = now.month;

    final daysInMonth = DateUtils.getDaysInMonth(year, month);
    final firstDay = DateTime(year, month, 1);
    final firstWeekday = firstDay.weekday;

    const weekdayLabels = ['ПН', 'ВТ', 'СР', 'ЧТ', 'ПТ', 'СБ', 'ВС'];

    final cells = <Widget>[];

    for (final label in weekdayLabels) {
      cells.add(
        Center(
          child: Text(
            label,
            style: TextStyle(
              color: AppColors.primary.withOpacity(0.7),
              fontSize: 10,
            ),
          ),
        ),
      );
    }

    for (int i = 1; i < firstWeekday; i++) {
      cells.add(const SizedBox());
    }

    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(year, month, day);
      final isActive = _activityDays.contains(_dateKey(date));

      cells.add(
        Center(
          child: Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: isActive
                ? const BoxDecoration(
                    color: Color(0x33B65A6A),
                    shape: BoxShape.circle,
                  )
                : null,
            child: Text(
              '$day',
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 13,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.primary),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                '${_monthNameRu(month)} $year',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              const Icon(Icons.chevron_left, color: AppColors.primary, size: 18),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right, color: AppColors.primary, size: 18),
            ],
          ),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 4,
            childAspectRatio: 1.05,
            children: cells,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = (_profile?['name'] ?? 'Пользователь').toString();
    final age = _calculateAge(_profile?['birth_date']);
    final streak = _calculateStreak();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Профиль'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Scrollbar(
              thumbVisibility: true,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(
                      color: AppColors.primary,
                      thickness: 1,
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.primary),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const CircleAvatar(
                            radius: 24,
                            backgroundColor: AppColors.primary,
                            child: Icon(
                              Icons.person,
                              color: AppColors.background,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    age > 0 ? '$age год' : 'Возраст не указан',
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const EditProfileScreen(),
                                ),
                              );
                              _loadData();
                            },
                            child: const Text(
                              'Редактировать',
                              style: TextStyle(
                                decoration: TextDecoration.underline,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Divider(
                      color: AppColors.primary,
                      thickness: 1,
                    ),
                    const SizedBox(height: 8),
                    const Center(
                      child: Text(
                        'Прогресс',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: Text(
                        'Вы учитесь $streak день подряд',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildCalendar(),
                    const SizedBox(height: 16),
                    const Divider(
                      color: AppColors.primary,
                      thickness: 1,
                    ),
                    const SizedBox(height: 8),
                    const Center(
                      child: Text(
                        'Карта интересов',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: SizedBox(
                        width: 320,
                        height: 320,
                        child: CustomPaint(
                          painter: _InterestMapPainter(
                            labels: _interestLabels,
                            values: _interestValues,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Divider(
                      color: AppColors.primary,
                      thickness: 1,
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _signOut,
                        child: const Text(
                          'Выйти',
                          style: TextStyle(
                            decoration: TextDecoration.underline,
                            fontSize: 16,
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

class _InterestMapPainter extends CustomPainter {
  final List<String> labels;
  final List<double> values;

  _InterestMapPainter({
    required this.labels,
    required this.values,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (labels.isEmpty || values.isEmpty || labels.length != values.length) return;

    final center = Offset(size.width / 2, size.height / 2 + 6);
    final radius = min(size.width, size.height) * 0.28;
    const levels = 5;
    final axesCount = labels.length;

    final gridPaint = Paint()
      ..color = AppColors.primary.withOpacity(0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;

    final axisPaint = Paint()
      ..color = AppColors.primary.withOpacity(0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final dataFillPaint = Paint()
      ..color = AppColors.primary.withOpacity(0.15)
      ..style = PaintingStyle.fill;

    final dataStrokePaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final pointPaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.fill;

    List<Offset> polygonPoints(double currentRadius) {
      return List.generate(axesCount, (index) {
        final angle = -pi / 2 + (2 * pi / axesCount) * index;
        return Offset(
          center.dx + currentRadius * cos(angle),
          center.dy + currentRadius * sin(angle),
        );
      });
    }

    for (int level = 1; level <= levels; level++) {
      final levelRadius = radius * (level / levels);
      final points = polygonPoints(levelRadius);
      final path = Path()..addPolygon(points, true);
      canvas.drawPath(path, gridPaint);
    }

    final outerPoints = polygonPoints(radius);
    for (final point in outerPoints) {
      canvas.drawLine(center, point, axisPaint);
    }

    final dataPoints = List.generate(axesCount, (index) {
      final normalized = (values[index].clamp(0, 100)) / 100;
      final pointRadius = radius * normalized;
      final angle = -pi / 2 + (2 * pi / axesCount) * index;

      return Offset(
        center.dx + pointRadius * cos(angle),
        center.dy + pointRadius * sin(angle),
      );
    });

    final dataPath = Path()..addPolygon(dataPoints, true);
    canvas.drawPath(dataPath, dataFillPaint);
    canvas.drawPath(dataPath, dataStrokePaint);

    for (final point in dataPoints) {
      canvas.drawCircle(point, 3, pointPaint);
    }

    for (int i = 0; i < labels.length; i++) {
      final angle = -pi / 2 + (2 * pi / axesCount) * i;
      final labelRadius = radius + 26;

      final labelOffset = Offset(
        center.dx + labelRadius * cos(angle),
        center.dy + labelRadius * sin(angle),
      );

      final textPainter = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: 9,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout(maxWidth: 72);

      textPainter.paint(
        canvas,
        Offset(
          labelOffset.dx - textPainter.width / 2,
          labelOffset.dy - textPainter.height / 2,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _InterestMapPainter oldDelegate) {
    return oldDelegate.labels != labels || oldDelegate.values != values;
  }
}