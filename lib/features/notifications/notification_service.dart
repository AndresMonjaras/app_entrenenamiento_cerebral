import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Servicio singleton de notificaciones locales para Los Mojarrules.
/// Muestra un recordatorio aleatorio cada hora.
class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();

  static const _channelId = 'mojarrules_reminder';
  static const _channelName = 'Recordatorios Mojarrules';
  static const _notifId = 0;

  static const _messages = [
    'Hora de poner a prueba esos mojarrules',
    'Ya es hora de freir la mojarra',
    'Mojarra que se duerme se lo lleva la corriente',
  ];

  Future<void> init() async {
    // This service configures native Android/iOS notifications. Other targets
    // must still be able to open the training app without a native plugin.
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return;
    }
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );

    // Solicitar permiso en Android 13+
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();

    await _scheduleHourly();
  }

  Future<void> _scheduleHourly() async {
    final message = _messages[Random().nextInt(_messages.length)];

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'Te recuerda practicar cada hora',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const notifDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _plugin.periodicallyShow(
      _notifId,
      '🐟 Los Mojarrules',
      message,
      RepeatInterval.hourly,
      notifDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  Future<void> cancelAll() => _plugin.cancelAll();
}
