import 'package:flutter/services.dart';

/// Manages the Android Foreground Service that keeps the app alive in background.
class ForegroundServiceManager {
  static const _channel = MethodChannel('com.example.course_schedule_app/service');

  static Future<void> start() async {
    try {
      await _channel.invokeMethod('startForegroundService');
    } catch (_) {}
  }

  static Future<void> stop() async {
    try {
      await _channel.invokeMethod('stopForegroundService');
    } catch (_) {}
  }
}
