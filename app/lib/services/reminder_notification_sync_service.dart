import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'notification_service.dart';

class ReminderNotificationSyncResult {
  const ReminderNotificationSyncResult({
    required this.succeeded,
    required this.skipped,
    required this.scheduledCount,
    this.message,
  });

  final bool succeeded;
  final bool skipped;
  final int scheduledCount;
  final String? message;
}

class ReminderNotificationSyncService {
  ReminderNotificationSyncService._();

  static final ReminderNotificationSyncService instance =
      ReminderNotificationSyncService._();

  Future<ReminderNotificationSyncResult> syncCurrentUserReminders({
    required String apiBaseUrl,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('user_id');
      if (userId == null || userId <= 0) {
        return const ReminderNotificationSyncResult(
          succeeded: false,
          skipped: true,
          scheduledCount: 0,
          message: 'Missing current user id',
        );
      }

      final prescriptionResponse = await http
          .get(
            Uri.parse('$apiBaseUrl/medications/api/prescriptions/$userId/'),
            headers: {
              'Accept': 'application/json',
              'X-User-Id': userId.toString(),
            },
          )
          .timeout(const Duration(seconds: 15));
      final prescriptionPayload = _decodeMap(prescriptionResponse.bodyBytes);
      if (!_isSuccessful(
        prescriptionResponse.statusCode,
        prescriptionPayload,
      )) {
        return _failed(prescriptionPayload, 'Unable to load prescriptions');
      }

      final rawPrescriptions = prescriptionPayload?['data'];
      if (rawPrescriptions is! List) {
        return _failed(
          prescriptionPayload,
          'Invalid prescription response data',
        );
      }

      final prescriptionIds = <int>[];
      for (final rawPrescription in rawPrescriptions) {
        if (rawPrescription is! Map) {
          return _failed(
            prescriptionPayload,
            'Invalid prescription response item',
          );
        }
        final prescription = Map<String, dynamic>.from(rawPrescription);
        final prescriptionId = _positiveInt(
          prescription['prescription_id'] ?? prescription['id'],
        );
        if (prescriptionId == null) {
          return _failed(prescriptionPayload, 'Prescription id is missing');
        }
        prescriptionIds.add(prescriptionId);
      }

      final reminders = <MedicationReminderNotification>[];
      for (final prescriptionId in prescriptionIds.toSet()) {
        final uri = Uri.parse('$apiBaseUrl/medications/api/reminders/list/')
            .replace(
              queryParameters: {
                'prescription_id': prescriptionId.toString(),
                'user_id': userId.toString(),
                'active_only': 'false',
              },
            );
        final response = await http
            .get(
              uri,
              headers: {
                'Accept': 'application/json',
                'X-User-Id': userId.toString(),
              },
            )
            .timeout(const Duration(seconds: 15));
        final payload = _decodeMap(response.bodyBytes);
        if (!_isSuccessful(response.statusCode, payload)) {
          return _failed(payload, 'Unable to load reminder settings');
        }

        final rawReminders = payload?['data'];
        if (rawReminders is! List) {
          return _failed(payload, 'Invalid reminder response data');
        }
        for (final rawReminder in rawReminders) {
          if (rawReminder is! Map) {
            return _failed(payload, 'Invalid reminder response item');
          }
          final reminder = MedicationReminderNotification.tryParse(
            Map<String, dynamic>.from(rawReminder),
          );
          if (reminder == null) {
            return _failed(payload, 'Reminder response fields are incomplete');
          }
          reminders.add(reminder);
        }
      }

      final result = await NotificationService.instance.syncMedicationReminders(
        reminders,
      );
      return ReminderNotificationSyncResult(
        succeeded: true,
        skipped: false,
        scheduledCount: result.scheduledCount,
      );
    } catch (error, stackTrace) {
      debugPrint('Reminder notification sync failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return ReminderNotificationSyncResult(
        succeeded: false,
        skipped: false,
        scheduledCount: 0,
        message: error.toString(),
      );
    }
  }

  Map<String, dynamic>? _decodeMap(List<int> bodyBytes) {
    try {
      final decoded = json.decode(utf8.decode(bodyBytes));
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } catch (_) {
      return null;
    }
  }

  bool _isSuccessful(int statusCode, Map<String, dynamic>? payload) {
    return statusCode >= 200 &&
        statusCode < 300 &&
        payload?['status'] == 'success';
  }

  ReminderNotificationSyncResult _failed(
    Map<String, dynamic>? payload,
    String fallback,
  ) {
    final backendMessage = payload?['message'];
    return ReminderNotificationSyncResult(
      succeeded: false,
      skipped: false,
      scheduledCount: 0,
      message: backendMessage is String && backendMessage.trim().isNotEmpty
          ? backendMessage.trim()
          : fallback,
    );
  }

  int? _positiveInt(dynamic value) {
    final parsed = value is int ? value : int.tryParse(value?.toString() ?? '');
    return parsed != null && parsed > 0 ? parsed : null;
  }
}
