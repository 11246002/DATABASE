import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class MedicationReminderNotification {
  const MedicationReminderNotification({
    required this.remindId,
    required this.remindTime,
    required this.isActive,
    required this.isExpired,
    required this.startDate,
    required this.endDate,
    this.drugName,
  });

  final int remindId;
  final String remindTime;
  final bool isActive;
  final bool isExpired;
  final DateTime startDate;
  final DateTime endDate;
  final String? drugName;

  static MedicationReminderNotification? tryParse(Map<String, dynamic> json) {
    final remindId = _positiveInt(json['remind_id']);
    final remindTime = _normalizedTime(json['remind_time']);
    final isActive = json['is_active'];
    final isExpired = json['is_expired'];
    final startDate = _dateOnly(json['start_date']);
    final endDate = _dateOnly(json['end_date']);
    if (remindId == null ||
        remindTime == null ||
        isActive is! bool ||
        isExpired is! bool ||
        startDate == null ||
        endDate == null ||
        endDate.isBefore(startDate)) {
      return null;
    }

    final rawName = json['raw_name'];
    return MedicationReminderNotification(
      remindId: remindId,
      remindTime: remindTime,
      isActive: isActive,
      isExpired: isExpired,
      startDate: startDate,
      endDate: endDate,
      drugName: rawName is String && rawName.trim().isNotEmpty
          ? rawName.trim()
          : null,
    );
  }

  static int? _positiveInt(dynamic value) {
    final parsed = value is int ? value : int.tryParse(value?.toString() ?? '');
    return parsed != null && parsed > 0 ? parsed : null;
  }

  static String? _normalizedTime(dynamic value) {
    if (value is! String) return null;
    final match = RegExp(r'^(\d{2}):(\d{2})(?::\d{2})?$').firstMatch(value);
    if (match == null) return null;
    final hour = int.tryParse(match.group(1)!);
    final minute = int.tryParse(match.group(2)!);
    if (hour == null || minute == null || hour > 23 || minute > 59) {
      return null;
    }
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  static DateTime? _dateOnly(dynamic value) {
    if (value is! String) return null;
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return null;
    return DateTime(parsed.year, parsed.month, parsed.day);
  }
}

class NotificationSyncResult {
  const NotificationSyncResult({
    required this.scheduledCount,
    required this.skippedInvalidCount,
  });

  final int scheduledCount;
  final int skippedInvalidCount;
}

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const String _channelId = 'medication_reminders';
  static const String _channelName = '服藥提醒';
  static const String _payloadPrefix = 'medication_reminder:';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _timezoneReady = false;

  bool get _isSupportedAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<bool> initialize() async {
    if (!_isSupportedAndroid) return false;
    if (_initialized) return _timezoneReady;

    try {
      tz_data.initializeTimeZones();
      final timezoneInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezoneInfo.identifier));
      _timezoneReady = true;

      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      final initialized = await _plugin.initialize(
        settings: const InitializationSettings(android: androidSettings),
        onDidReceiveNotificationResponse: _onNotificationResponse,
      );
      _initialized = initialized ?? false;
    } catch (error, stackTrace) {
      debugPrint('Notification initialization failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      _initialized = false;
      _timezoneReady = false;
    }
    return _initialized && _timezoneReady;
  }

  Future<void> requestNotificationPermission() async {
    if (!await initialize()) return;
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return;

    try {
      final notificationsAllowed = await android
          .requestNotificationsPermission();
      if (notificationsAllowed == false) return;
      final canScheduleExactly =
          await android.canScheduleExactNotifications() ?? false;
      if (!canScheduleExactly) {
        await android.requestExactAlarmsPermission();
      }
    } catch (error) {
      debugPrint('Notification permission request failed: $error');
    }
  }

  Future<int> scheduleMedicationReminder(
    MedicationReminderNotification reminder,
  ) async {
    if (!_isSupportedAndroid) return 0;
    if (!await initialize()) {
      throw StateError('Notification service is unavailable');
    }
    await cancelMedicationReminder(reminder.remindId);
    if (!reminder.isActive || reminder.isExpired) return 0;

    final timeParts = reminder.remindTime.split(':');
    final hour = int.parse(timeParts[0]);
    final minute = int.parse(timeParts[1]);
    final now = tz.TZDateTime.now(tz.local);
    final today = DateTime(now.year, now.month, now.day);
    var date = reminder.startDate.isAfter(today) ? reminder.startDate : today;
    var scheduledCount = 0;

    while (!date.isAfter(reminder.endDate)) {
      final scheduledDate = tz.TZDateTime(
        tz.local,
        date.year,
        date.month,
        date.day,
        hour,
        minute,
      );
      if (scheduledDate.isAfter(now)) {
        final notificationId = scheduledCount == 0
            ? reminder.remindId
            : _occurrenceId(reminder.remindId, date);
        await _scheduleOne(
          id: notificationId,
          scheduledDate: scheduledDate,
          reminder: reminder,
        );
        scheduledCount++;
      }
      date = date.add(const Duration(days: 1));
    }
    return scheduledCount;
  }

  Future<void> rescheduleMedicationReminder(
    MedicationReminderNotification reminder,
  ) async {
    await scheduleMedicationReminder(reminder);
  }

  Future<void> cancelMedicationReminder(int remindId) async {
    if (!_isSupportedAndroid) return;
    if (!await initialize()) {
      throw StateError('Notification service is unavailable');
    }
    final expectedPayload = '$_payloadPrefix$remindId';
    try {
      final pending = await _plugin.pendingNotificationRequests();
      for (final request in pending) {
        if (request.payload == expectedPayload) {
          await _plugin.cancel(id: request.id);
        }
      }
      await _plugin.cancel(id: remindId);
    } catch (error) {
      debugPrint('Cancel notification $remindId failed: $error');
      rethrow;
    }
  }

  Future<NotificationSyncResult> syncMedicationReminders(
    Iterable<MedicationReminderNotification> reminders,
  ) async {
    if (!_isSupportedAndroid) {
      return const NotificationSyncResult(
        scheduledCount: 0,
        skippedInvalidCount: 0,
      );
    }
    if (!await initialize()) {
      throw StateError('Notification service is unavailable');
    }

    final byId = <int, MedicationReminderNotification>{
      for (final reminder in reminders) reminder.remindId: reminder,
    };
    final pending = await _plugin.pendingNotificationRequests();
    final staleIds = <int>{};
    for (final request in pending) {
      final remindId = _remindIdFromPayload(request.payload);
      if (remindId != null && !byId.containsKey(remindId)) {
        staleIds.add(remindId);
      }
    }
    for (final staleId in staleIds) {
      await cancelMedicationReminder(staleId);
    }

    var scheduledCount = 0;
    for (final reminder in byId.values) {
      scheduledCount += await scheduleMedicationReminder(reminder);
    }
    return NotificationSyncResult(
      scheduledCount: scheduledCount,
      skippedInvalidCount: 0,
    );
  }

  Future<void> _scheduleOne({
    required int id,
    required tz.TZDateTime scheduledDate,
    required MedicationReminderNotification reminder,
  }) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: '按服藥提醒設定時間顯示本機通知',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        largeIcon: DrawableResourceAndroidBitmap('drug_app_logo'),
        category: AndroidNotificationCategory.reminder,
      ),
    );
    final body = reminder.drugName == null
        ? '請依照藥單服用您的藥物'
        : '該服用 ${reminder.drugName} 了';
    final payload = '$_payloadPrefix${reminder.remindId}';
    final scheduleMode = await _androidScheduleMode();

    try {
      await _plugin.zonedSchedule(
        id: id,
        title: '智慧藥管家｜服藥提醒',
        body: body,
        scheduledDate: scheduledDate,
        notificationDetails: details,
        androidScheduleMode: scheduleMode,
        payload: payload,
      );
    } on PlatformException catch (error) {
      if (scheduleMode != AndroidScheduleMode.inexactAllowWhileIdle) {
        await _plugin.zonedSchedule(
          id: id,
          title: '智慧藥管家｜服藥提醒',
          body: body,
          scheduledDate: scheduledDate,
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: payload,
        );
      } else {
        rethrow;
      }
      debugPrint('Exact alarm unavailable; used inexact alarm: $error');
    }
  }

  Future<AndroidScheduleMode> _androidScheduleMode() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final canScheduleExactly =
        await android?.canScheduleExactNotifications() ?? false;
    return canScheduleExactly
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
  }

  int _occurrenceId(int remindId, DateTime date) {
    final dateValue = date.year * 10000 + date.month * 100 + date.day;
    final mixed = (remindId * 1000003) ^ dateValue;
    final positive = mixed & 0x7fffffff;
    if (positive == 0 || positive == remindId) {
      return (positive + 1) & 0x7fffffff;
    }
    return positive;
  }

  int? _remindIdFromPayload(String? payload) {
    if (payload == null || !payload.startsWith(_payloadPrefix)) return null;
    return int.tryParse(payload.substring(_payloadPrefix.length));
  }

  void _onNotificationResponse(NotificationResponse response) {
    // Tapping a notification opens/resumes the app. No deep-link behavior is
    // added here so the existing navigation and Reminder UI stay unchanged.
  }
}
