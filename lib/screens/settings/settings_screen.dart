import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../services/settings_service.dart';
// import '../../services/notification_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _settingsService = SettingsService();

  bool _isLoading = true;
  bool _dailyNotifications = false;
  String _notificationTime = '09:00';
  bool _isRussian = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final notifications = await _settingsService.getDailyNotifications();
    final time = await _settingsService.getNotificationTime();

    if (!mounted) return;

    setState(() {
      _dailyNotifications = notifications;
      _notificationTime = time;
      _isLoading = false;
    });
  }

  Future<void> _pickTime() async {
    if (!_dailyNotifications) return;

    final parts = _notificationTime.split(':');
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.tryParse(parts[0]) ?? 9,
        minute: int.tryParse(parts[1]) ?? 00,
      ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null) return;

    final formatted =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';

    await _settingsService.setNotificationTime(formatted);

    // if (_dailyNotifications) {
    //   await NotificationService.instance.scheduleDailyNotification(picked);
    // }

    if (!mounted) return;

    setState(() {
      _notificationTime = formatted;
    });
  }

  Future<void> _toggleNotifications(bool value) async {
    await _settingsService.setDailyNotifications(value);

    // if (value) {
    //   if (kIsWeb && mounted) {
    //     ScaffoldMessenger.of(context).showSnackBar(
    //       const SnackBar(
    //         content: Text('Уведомления работают в мобильной сборке приложения'),
    //       ),
    //     );
    //   }

    //   final parts = _notificationTime.split(':');
    //   final time = TimeOfDay(
    //     hour: int.tryParse(parts[0]) ?? 9,
    //     minute: int.tryParse(parts[1]) ?? 41,
    //   );
    //   await NotificationService.instance.scheduleDailyNotification(time);
    // } else {
    //   await NotificationService.instance.cancelDailyNotification();
    // }

    if (!mounted) return;

    setState(() {
      _dailyNotifications = value;
    });
  }

  Widget _buildSectionDivider() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 18),
      height: 1,
      color: AppColors.primary,
    );
  }

  Widget _buildSwitch({
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Switch(
      value: value,
      onChanged: onChanged,
      activeColor: AppColors.background,
      activeTrackColor: AppColors.primary,
      inactiveThumbColor: AppColors.primary,
      inactiveTrackColor: Colors.transparent,
      trackOutlineColor: WidgetStateProperty.resolveWith<Color?>(
        (states) => AppColors.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.headlineMedium?.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w500,
          fontSize: 22,
        );

    const sectionTitleStyle = TextStyle(
      color: AppColors.primary,
      fontSize: 15,
      fontWeight: FontWeight.w400,
    );

    final disabledColor = AppColors.primary.withOpacity(0.45);
    final enabledColor = AppColors.primary;

    return Scaffold(
      appBar: AppBar(
        title: Text('Настройки', style: titleStyle),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionDivider(),
                    InkWell(
                      onTap: () {
                        Navigator.pushNamed(context, '/edit-preferences');
                      },
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Редактировать предпочтения',
                                style: sectionTitleStyle,
                              ),
                            ),
                            Icon(
                              Icons.chevron_right,
                              color: AppColors.primary,
                            ),
                          ],
                        ),
                      ),
                    ),
                    _buildSectionDivider(),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Expanded(
                          child: Text(
                            'Ежедневные\nуведомления',
                            style: sectionTitleStyle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Row(
                          children: [
                            Text(
                              'OFF',
                              style: TextStyle(
                                color: AppColors.primary.withOpacity(0.65),
                                fontSize: 12,
                              ),
                            ),
                            _buildSwitch(
                              value: _dailyNotifications,
                              onChanged: _toggleNotifications,
                            ),
                            Text(
                              'ON',
                              style: TextStyle(
                                color: AppColors.primary.withOpacity(0.65),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Время уведомлений',
                            style: TextStyle(
                              color: _dailyNotifications
                                  ? enabledColor
                                  : disabledColor,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: _dailyNotifications ? _pickTime : null,
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 150),
                            opacity: _dailyNotifications ? 1 : 0.55,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: _dailyNotifications
                                    ? AppColors.primary.withOpacity(0.35)
                                    : AppColors.primary.withOpacity(0.16),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                _notificationTime,
                                style: TextStyle(
                                  color: _dailyNotifications
                                      ? enabledColor
                                      : disabledColor,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    _buildSectionDivider(),
                    InkWell(
                      onTap: () {
                        Navigator.pushNamed(context, '/history');
                      },
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'История просмотров',
                                style: sectionTitleStyle,
                              ),
                            ),
                            Icon(
                              Icons.chevron_right,
                              color: AppColors.primary,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Сменить язык',
                            style: sectionTitleStyle,
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              'ENG',
                              style: TextStyle(
                                color: !_isRussian
                                    ? AppColors.primary
                                    : AppColors.primary.withOpacity(0.6),
                                fontSize: 13,
                              ),
                            ),
                            _buildSwitch(
                              value: _isRussian,
                              onChanged: (value) {
                                setState(() {
                                  _isRussian = value;
                                });
                              },
                            ),
                            Text(
                              'RU',
                              style: TextStyle(
                                color: _isRussian
                                    ? AppColors.primary
                                    : AppColors.primary.withOpacity(0.6),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}