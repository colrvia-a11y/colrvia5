import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../main.dart';
import '../screens/visualizer_screen.dart';
import 'analytics_service.dart';

class NotificationsService {
  NotificationsService._();
  static final NotificationsService instance = NotificationsService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    await _local.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: _onLocalResponse,
    );

    await _messaging.requestPermission();
    final token = await _messaging.getToken();
    if (token != null) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await _messaging.subscribeToTopic('user_$uid');
        AnalyticsService.instance.log('push_token_registered');
      }
    }

    FirebaseMessaging.onMessage.listen((m) {
      AnalyticsService.instance
          .log('push_received', {'type': m.data['type']});
      if (m.notification != null) {
        _showLocal(m);
      }
    });
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);
  }

  void _showLocal(RemoteMessage m) {
    _local.show(
      0,
      m.notification?.title ?? 'Update',
      m.notification?.body ?? '',
      const NotificationDetails(
        android: AndroidNotificationDetails('default', 'Default'),
        iOS: DarwinNotificationDetails(),
      ),
      payload: jsonEncode(m.data),
    );
  }

  void _onLocalResponse(NotificationResponse resp) {
    final payload = resp.payload;
    if (payload != null) {
      _handlePayload(payload);
    }
  }

  void _handleMessage(RemoteMessage message) {
    _handlePayload(jsonEncode(message.data));
  }

  void _handlePayload(String payload) {
    final data = jsonDecode(payload);
    if (data['type'] == 'viz_hq_complete') {
      final projectId = data['projectId'] as String?;
      final jobId = data['jobId'] as String?;
      MyApp.navigatorKey.currentState?.push(MaterialPageRoute(
          builder: (_) => VisualizerScreen(
                projectId: projectId,
                jobId: jobId,
              )));
      AnalyticsService.instance
          .log('viz_hq_push_opened', {'jobId': jobId});
    }
  }

  Future<void> scheduleNudge(
      String kind, String title, String body, Duration delay) async {
    await _local.schedule(
      kind.hashCode,
      title,
      body,
      DateTime.now().add(delay),
      const NotificationDetails(
        android: AndroidNotificationDetails('nudges', 'Nudges'),
        iOS: DarwinNotificationDetails(),
      ),
    );
    AnalyticsService.instance
        .logEvent('lifecycle_nudge_sent', {'kind': kind});
  }
}
