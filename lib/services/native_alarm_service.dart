import 'package:flutter/services.dart';

/// Native Android notification helpers via MethodChannel.
class NativeAlarmService {
  static const _channel = MethodChannel('com.example.course_schedule_app/alarm');

  /// Post a notification immediately.
  static Future<void> fireImmediate({
    required int id,
    required int notifyId,
    required String title,
    required String body,
  }) async {
    try {
      await _channel.invokeMethod('fireImmediate', {
        'id': id,
        'notifyId': notifyId,
        'title': title,
        'body': body,
      });
    } catch (_) {}
  }

  /// Cancel a notification by its notifyId.
  static Future<void> cancelNotification(int notifyId) async {
    try {
      await _channel.invokeMethod('cancelNotification', {'notifyId': notifyId});
    } catch (_) {}
  }
}
