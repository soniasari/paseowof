import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;

class LocalNotificationService {
  static final LocalNotificationService _instance = LocalNotificationService._internal();
  factory LocalNotificationService() => _instance;
  LocalNotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Inicializa el servicio de notificaciones locales
  Future<void> initialize() async {
    if (_initialized) return;

    // Inicializar timezone
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('America/La_Paz')); // Zona horaria de Bolivia

    // Configuración para Android
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // Configuración para iOS
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

    // Solicitar permisos en Android 13+
    if (await _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>() != null) {
      await _notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }

    _initialized = true;
  }

  /// Maneja cuando se toca una notificación
  void _onNotificationTapped(NotificationResponse response) {
    // Aquí puedes manejar la navegación cuando se toca la notificación
    // Por ahora no hacemos nada específico
  }

  /// Programa una notificación para un paseo
  /// [walkId] ID único del paseo (se usa como notificationId)
  /// [title] Título de la notificación
  /// [body] Cuerpo de la notificación
  /// [scheduledDate] Fecha y hora en que se debe mostrar la notificación
  Future<void> scheduleWalkNotification({
    required int walkId,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    // Convertir DateTime a TZDateTime
    final tzScheduledDate = tz.TZDateTime.from(scheduledDate, tz.local);
    final tzAhora = tz.TZDateTime.now(tz.local);

    // Verificar que la fecha no sea en el pasado
    if (tzScheduledDate.isBefore(tzAhora)) {
      return;
    }

    // Configuración para Android
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

  /// Cancela una notificación programada
  Future<void> cancelNotification(int notificationId) async {
    await _notifications.cancel(notificationId);
  }

  /// Cancela todas las notificaciones
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  /// Verifica si el servicio está inicializado
  bool get isInitialized => _initialized;

  /// Verifica los permisos de notificaciones
  Future<bool> checkPermissions() async {
    if (!_initialized) {
      await initialize();
    }

    // Para Android 13+
    final androidImplementation = await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidImplementation != null) {
      final granted = await androidImplementation.requestNotificationsPermission();
      return granted ?? false;
    }

    // Para iOS
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

    return true; // Asumir que está permitido en otras plataformas
  }

  /// Obtiene todas las notificaciones programadas pendientes
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    if (!_initialized) {
      await initialize();
    }
    return await _notifications.pendingNotificationRequests();
  }

  /// Muestra una notificación de prueba inmediata
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

  /// Programa una notificación de prueba para dentro de X segundos
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

  /// Obtiene información de estado del servicio
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

  /// Programa una notificación para cuando toque el paseo (en la hora de inicio)
  Future<void> scheduleWalkStartNotification({
    required String walkId,
    required String propietarioNombre,
    required List<String> caninoNombres,
    required DateTime fechaPaseo,
    required String horaInicio,
    String? direccion,
  }) async {
    // Parsear la hora de inicio
    final horaParts = horaInicio.split(':');
    final hora = int.parse(horaParts[0]);
    final minuto = int.parse(horaParts[1]);

    // Crear TZDateTime directamente en la zona horaria local
    // Esto evita problemas de conversión de zona horaria
    final tzLocal = tz.local;
    final fechaHoraInicio = tz.TZDateTime(
      tzLocal,
      fechaPaseo.year,
      fechaPaseo.month,
      fechaPaseo.day,
      hora,
      minuto,
    );

    // Usar el hash del walkId como notificationId (convertir string a int)
    final notificationId = walkId.hashCode.abs();

    final caninosText = caninoNombres.join(', ');
    final direccionText = direccion != null && direccion.isNotEmpty ? '\n📍 $direccion' : '';

    // Pasar directamente el TZDateTime
    await scheduleWalkNotificationTZ(
      walkId: notificationId,
      title: '🐕 ¡Es hora del paseo!',
      body: 'Paseo con $caninosText\n👤 Propietario: $propietarioNombre$direccionText',
      scheduledDate: fechaHoraInicio,
    );
  }

  /// Programa una notificación de recordatorio (15 minutos antes)
  Future<void> scheduleWalkReminderNotification({
    required String walkId,
    required String propietarioNombre,
    required List<String> caninoNombres,
    required DateTime fechaPaseo,
    required String horaInicio,
  }) async {
    // Parsear la hora de inicio
    final horaParts = horaInicio.split(':');
    final hora = int.parse(horaParts[0]);
    final minuto = int.parse(horaParts[1]);

    // Crear TZDateTime directamente en la zona horaria local
    final tzLocal = tz.local;
    final fechaHoraInicio = tz.TZDateTime(
      tzLocal,
      fechaPaseo.year,
      fechaPaseo.month,
      fechaPaseo.day,
      hora,
      minuto,
    );

    // Restar 15 minutos para el recordatorio
    final fechaRecordatorio = fechaHoraInicio.subtract(const Duration(minutes: 15));

    // Verificar que el recordatorio no esté en el pasado
    final tzAhora = tz.TZDateTime.now(tz.local);
    
    if (fechaRecordatorio.isBefore(tzAhora)) {
      return;
    }

    // Usar el hash del walkId + 1 como notificationId para el recordatorio
    final notificationId = (walkId.hashCode.abs() + 1);

    final caninosText = caninoNombres.join(', ');

    // Pasar directamente el TZDateTime
    await scheduleWalkNotificationTZ(
      walkId: notificationId,
      title: '⏰ Recordatorio de Paseo',
      body: 'En 15 minutos: Paseo con $caninosText\n👤 Propietario: $propietarioNombre',
      scheduledDate: fechaRecordatorio,
    );
  }

  /// Versión mejorada que acepta TZDateTime directamente
  /// Esto evita problemas de conversión de zona horaria
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

    // Verificar que la fecha no sea en el pasado
    if (scheduledDate.isBefore(tzAhora)) {
      return;
    }

    // Configuración para Android
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

