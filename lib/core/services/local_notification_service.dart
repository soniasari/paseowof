import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;

class LocalNotificationService {
  static final LocalNotificationService _instance = LocalNotificationService._internal();
  factory LocalNotificationService() => _instance;
  LocalNotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Arrancamos el servicio de notificaciones (timezone Bolivia, Android e iOS)
  Future<void> initialize() async {
    if (_initialized) return;

    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('America/La_Paz')); // Bolivia

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Pedir permisos en Android 13+
    if (await _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>() != null) {
      await _notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }

    _initialized = true;
  }

  /// Cuando el usuario toca la noti (acá se podría abrir una pantalla)
  void _onNotificationTapped(NotificationResponse response) {
    // Por ahora no hacemos nada
  }

  /// Programa una noti para un paseo (walkId = id de la noti, título, cuerpo, fecha/hora)
  Future<void> scheduleWalkNotification({
    required int walkId,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    final tzScheduledDate = tz.TZDateTime.from(scheduledDate, tz.local);
    final tzAhora = tz.TZDateTime.now(tz.local);

    if (tzScheduledDate.isBefore(tzAhora)) {
      return; // No programamos si ya pasó
    }

    const androidDetails = AndroidNotificationDetails(
      'paseos_channel',
      'Paseos Programados',
      channelDescription: 'Notificaciones para recordar paseos programados',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    // Configuración para iOS
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await _notifications.zonedSchedule(
        walkId, // Usar walkId como notificationId único
        title,
        body,
        tzScheduledDate,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e, stackTrace) {
      rethrow;
    }
  }

  /// Cancela una noti por su id
  Future<void> cancelNotification(int notificationId) async {
    await _notifications.cancel(notificationId);
  }

  /// Cancela todas las notis
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  bool get isInitialized => _initialized;

  /// Revisa si tenemos permiso para mostrar notis
  Future<bool> checkPermissions() async {
    if (!_initialized) {
      await initialize();
    }

    final androidImplementation = await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidImplementation != null) {
      final granted = await androidImplementation.requestNotificationsPermission();
      return granted ?? false;
    }

    final iosImplementation = await _notifications
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    
    if (iosImplementation != null) {
      final granted = await iosImplementation.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }

    return true; // En otras plataformas asumimos que está ok
  }

  /// Lista de notis que todavía no se mostraron
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    if (!_initialized) {
      await initialize();
    }
    return await _notifications.pendingNotificationRequests();
  }

  /// Muestra una noti de prueba al toque
  Future<void> showTestNotification() async {
    if (!_initialized) {
      await initialize();
    }

    const androidDetails = AndroidNotificationDetails(
      'paseos_channel',
      'Paseos Programados',
      channelDescription: 'Notificaciones para recordar paseos programados',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      999999, // ID de prueba
      '🧪 Notificación de Prueba',
      'Las notificaciones locales están funcionando correctamente',
      notificationDetails,
    );
  }

  /// Noti de prueba para dentro de X segundos
  Future<void> scheduleTestNotification({int seconds = 5}) async {
    if (!_initialized) {
      await initialize();
    }

    final scheduledDate = DateTime.now().add(Duration(seconds: seconds));
    final tzScheduledDate = tz.TZDateTime.from(scheduledDate, tz.local);

    const androidDetails = AndroidNotificationDetails(
      'paseos_channel',
      'Paseos Programados',
      channelDescription: 'Notificaciones para recordar paseos programados',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.zonedSchedule(
      999998, // ID de prueba
      '🧪 Notificación Programada de Prueba',
      'Esta notificación fue programada para $seconds segundos después',
      tzScheduledDate,
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Info del servicio (inicializado, permisos, notis pendientes)
  Future<Map<String, dynamic>> getServiceStatus() async {
    if (!_initialized) {
      await initialize();
    }

    final pending = await getPendingNotifications();
    final hasPermission = await checkPermissions();

    return {
      'initialized': _initialized,
      'hasPermission': hasPermission,
      'pendingNotifications': pending.length,
      'notifications': pending.map((n) => {
        'id': n.id,
        'title': n.title ?? 'Sin título',
        'body': n.body ?? 'Sin contenido',
      }).toList(),
    };
  }

  /// Noti para la hora de inicio del paseo
  Future<void> scheduleWalkStartNotification({
    required String walkId,
    required String propietarioNombre,
    required List<String> caninoNombres,
    required DateTime fechaPaseo,
    required String horaInicio,
    String? direccion,
  }) async {
    final horaParts = horaInicio.split(':');
    final hora = int.parse(horaParts[0]);
    final minuto = int.parse(horaParts[1]);

    final tzLocal = tz.local;
    final fechaHoraInicio = tz.TZDateTime(
      tzLocal,
      fechaPaseo.year,
      fechaPaseo.month,
      fechaPaseo.day,
      hora,
      minuto,
    );

    final notificationId = walkId.hashCode.abs();

    final caninosText = caninoNombres.join(', ');
    final direccionText = direccion != null && direccion.isNotEmpty ? '\n📍 $direccion' : '';

    await scheduleWalkNotificationTZ(
      walkId: notificationId,
      title: '🐕 ¡Es hora del paseo!',
      body: 'Paseo con $caninosText\n👤 Propietario: $propietarioNombre$direccionText',
      scheduledDate: fechaHoraInicio,
    );
  }

  /// Noti de recordatorio 15 min antes del paseo
  Future<void> scheduleWalkReminderNotification({
    required String walkId,
    required String propietarioNombre,
    required List<String> caninoNombres,
    required DateTime fechaPaseo,
    required String horaInicio,
  }) async {
    final horaParts = horaInicio.split(':');
    final hora = int.parse(horaParts[0]);
    final minuto = int.parse(horaParts[1]);

    final tzLocal = tz.local;
    final fechaHoraInicio = tz.TZDateTime(
      tzLocal,
      fechaPaseo.year,
      fechaPaseo.month,
      fechaPaseo.day,
      hora,
      minuto,
    );

    final fechaRecordatorio = fechaHoraInicio.subtract(const Duration(minutes: 15));
    final tzAhora = tz.TZDateTime.now(tz.local);
    
    if (fechaRecordatorio.isBefore(tzAhora)) {
      return; // No programamos si ya pasó
    }

    final notificationId = (walkId.hashCode.abs() + 1);
    final caninosText = caninoNombres.join(', ');

    await scheduleWalkNotificationTZ(
      walkId: notificationId,
      title: '⏰ Recordatorio de Paseo',
      body: 'En 15 minutos: Paseo con $caninosText\n👤 Propietario: $propietarioNombre',
      scheduledDate: fechaRecordatorio,
    );
  }

  /// Programa la noti con fecha ya en zona horaria (evita líos de conversión)
  Future<void> scheduleWalkNotificationTZ({
    required int walkId,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    final tzAhora = tz.TZDateTime.now(tz.local);

    if (scheduledDate.isBefore(tzAhora)) {
      return;
    }

    const androidDetails = AndroidNotificationDetails(
      'paseos_channel',
      'Paseos Programados',
      channelDescription: 'Notificaciones para recordar paseos programados',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await _notifications.zonedSchedule(
        walkId,
        title,
        body,
        scheduledDate, // Ya es TZDateTime, no necesita conversión
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e, stackTrace) {
      rethrow;
    }
  }
}

