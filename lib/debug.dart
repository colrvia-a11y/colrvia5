// lib/debug.dart
import 'package:flutter/foundation.dart';

class Debug {
  static void info(String screen, String method, String message) {
    if (kDebugMode) {
      print('[$screen] $method: $message');
    }
  }

  static void summary() {
    if (kDebugMode) {
      print('[Debug] Summary');
    }
  }

  static void postFrameCallback(String screen, String method, {String? details}) {
    if (kDebugMode) {
      print('[$screen] $method: Post frame callback. Details: $details');
    }
  }
}
