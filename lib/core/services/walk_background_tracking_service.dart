// =============================================================================
// WALK BACKGROUND TRACKING SERVICE
// =============================================================================
// El seguimiento en segundo plano solo se activa cuando el GPS está en uso
// (paseo iniciado). Al iniciar el paseo se arranca el servicio; al finalizar
// o cancelar se detiene. Estado compartido vía SharedPreferences.
// =============================================================================

import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/walks/domain/entities/gps_point.dart';
import '../../features/walks/data/services/walk_track_filter_service.dart';

const _keyStartTime = 'walk_track_start_time_iso';
const _keyPaused = 'walk_track_paused';
const _keyTotalPausedSec = 'walk_track_total_paused_seconds';
const _keyDistanceKm = 'walk_track_distance_km';
const _keyPaceMinPerKm = 'walk_track_pace_min_per_km';
const _keyAvgSpeedKmh = 'walk_track_avg_speed_kmh';
const _keyFinishRequested = 'walk_track_finish_requested';
const _keyCancelRequested = 'walk_track_cancel_requested';
const _keyPoints15 = 'walk_track_15_points';
const _keyFinished = 'walk_track_finished';
const _intervalSec = 15;

/// Punto de entrada del isolate en segundo plano. Solo se ejecuta cuando
/// el servicio está activo (GPS del paseo en uso).
@pragma('vm:entry-point')
Future<void> _walkTrackingOnStart(ServiceInstance instance) async {
  // Necesario para que los plugins (Geolocator, SharedPreferences) funcionen en este isolate.
  DartPluginRegistrant.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final startTimeStr = prefs.getString(_keyStartTime);
  if (startTimeStr == null) {
    instance.stopSelf();
    return;
  }

  instance.on('stop').listen((_) {
    instance.stopSelf();
  });

  final filter = WalkTrackFilterService();

  while (true) {
    if (prefs.getBool(_keyCancelRequested) == true) {
      await _clearPrefs(prefs);
      instance.stopSelf();
      return;
    }
    if (prefs.getBool(_keyFinishRequested) == true) {
      final points = filter.select15Points();
      if (points.isNotEmpty) {
        final list = points.map((p) => p.toMap()).toList();
        await prefs.setString(_keyPoints15, jsonEncode(list));
      }
      await prefs.setBool(_keyFinished, true);
      await _clearRequestFlags(prefs);
      instance.stopSelf();
      return;
    }
    if (prefs.getBool(_keyPaused) == true) {
      await Future<void>.delayed(const Duration(seconds: 1));
      continue;
    }

    try {
      // timeLimit evita que getCurrentPosition cuelgue el isolate si no hay fix GPS.
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5,
          timeLimit: Duration(seconds: 8),
        ),
      ).timeout(const Duration(seconds: 10));
      final result = filter.processPoint(
        latitude: position.latitude,
        longitude: position.longitude,
        timestamp: position.timestamp,
        accuracyMeters: position.accuracy,
      );
      if (result.accepted) {
        await prefs.setDouble(_keyDistanceKm, result.totalDistanceKm);
        if (result.currentPaceMinPerKm != null) {
          await prefs.setDouble(_keyPaceMinPerKm, result.currentPaceMinPerKm!);
        }
        if (result.averageSpeedKmh != null) {
          await prefs.setDouble(_keyAvgSpeedKmh, result.averageSpeedKmh!);
        }
      }
    } catch (_) {}

    await Future<void>.delayed(const Duration(seconds: _intervalSec));
  }
}

/// Wrapper para iOS (onForeground/onBackground requieren Future<bool>).
@pragma('vm:entry-point')
Future<bool> _walkTrackingOnStartIos(ServiceInstance instance) async {
  await _walkTrackingOnStart(instance);
  return true;
}

Future<void> _clearPrefs(SharedPreferences prefs) async {
  await prefs.remove(_keyStartTime);
  await prefs.remove(_keyPaused);
  await prefs.remove(_keyTotalPausedSec);
  await prefs.remove(_keyDistanceKm);
  await prefs.remove(_keyPaceMinPerKm);
  await prefs.remove(_keyAvgSpeedKmh);
  await prefs.remove(_keyFinishRequested);
  await prefs.remove(_keyCancelRequested);
  await prefs.remove(_keyPoints15);
  await prefs.remove(_keyFinished);
}

Future<void> _clearRequestFlags(SharedPreferences prefs) async {
  await prefs.remove(_keyFinishRequested);
  await prefs.remove(_keyCancelRequested);
}

/// Servicio que mantiene el seguimiento GPS en segundo plano solo mientras
/// el paseo está activo. Se inicia al empezar el paseo y se detiene al
/// finalizar o cancelar.
class WalkBackgroundTrackingService {
  static const String _channelId = 'paseo_en_curso';
  static const String _channelName = 'Paseo en curso';

  /// Inicializa la configuración del servicio. Llamar una vez al arranque (p. ej. main).
  static Future<void> initialize() async {
    if (Platform.isAndroid) {
      final plugin = FlutterLocalNotificationsPlugin();
      final android = plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        const channel = AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: 'GPS activo durante el paseo',
          importance: Importance.low,
          playSound: false,
        );
        await android.createNotificationChannel(channel);
      }
    }

    final service = FlutterBackgroundService();
    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: _walkTrackingOnStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: _channelId,
        initialNotificationTitle: _channelName,
        initialNotificationContent: 'GPS activo • Capturando puntos',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: _walkTrackingOnStartIos,
        onBackground: _walkTrackingOnStartIos,
      ),
    );
  }

  /// Inicia el seguimiento en segundo plano. Solo se debe llamar cuando el
  /// paseo está iniciado y el GPS está activo. Si el servicio ya estaba
  /// corriendo, lo detiene primero para que arranque un isolate nuevo y
  /// capture puntos y distancia.
  static Future<void> start() async {
    final service = FlutterBackgroundService();
    if (await service.isRunning()) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyCancelRequested, true);
      service.invoke('stop');
      for (int i = 0; i < 20; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
        if (!await service.isRunning()) break;
      }
      await _clearPrefs(prefs);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyStartTime, DateTime.now().toIso8601String());
    await prefs.setBool(_keyPaused, false);
    await prefs.setDouble(_keyTotalPausedSec, 0.0);
    await prefs.setDouble(_keyDistanceKm, 0.0);
    await prefs.setBool(_keyFinished, false);
    await prefs.remove(_keyPoints15);
    await prefs.remove(_keyCancelRequested);
    await prefs.remove(_keyFinishRequested);

    service.startService();
  }

  /// Detiene el servicio sin guardar (cancelar paseo).
  static Future<void> cancel() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyCancelRequested, true);
    final service = FlutterBackgroundService();
    service.invoke('stop');
  }

  /// Pide al servicio que finalice y guarde los 15 puntos.
  static Future<void> requestFinish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyFinishRequested, true);
  }

  /// Marca el paseo como pausado en el servicio (deja de capturar puntos).
  static Future<void> setPaused(bool paused) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyPaused, paused);
  }

  /// Actualiza el total de segundos pausados (llamar al reanudar).
  static Future<void> setTotalPausedSeconds(double seconds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyTotalPausedSec, seconds);
  }

  /// Lee el estado actual desde el servicio (para la UI).
  static Future<WalkBackgroundState?> getState() async {
    final prefs = await SharedPreferences.getInstance();
    final startStr = prefs.getString(_keyStartTime);
    if (startStr == null) return null;
    final startTime = DateTime.parse(startStr);
    final totalPaused = prefs.getDouble(_keyTotalPausedSec) ?? 0.0;
    final distanceKm = prefs.getDouble(_keyDistanceKm) ?? 0.0;
    final pace = prefs.getDouble(_keyPaceMinPerKm);
    final avgSpeed = prefs.getDouble(_keyAvgSpeedKmh);
    final finished = prefs.getBool(_keyFinished) ?? false;
    return WalkBackgroundState(
      startTime: startTime,
      totalPausedSeconds: totalPaused,
      distanceKm: distanceKm,
      currentPaceMinPerKm: pace,
      averageSpeedKmh: avgSpeed,
      finished: finished,
    );
  }

  /// Obtiene los 15 puntos tras finalizar. Debe llamarse después de que
  /// el servicio haya parado y escrito los puntos.
  static Future<List<GpsPoint>> get15Points() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_keyPoints15);
    if (jsonStr == null) return [];
    final list = jsonDecode(jsonStr) as List<dynamic>;
    return list.map((e) => GpsPoint.fromMap(Map<String, dynamic>.from(e as Map))).toList();
  }

  /// Limpia el estado tras subir los puntos (o tras cancelar).
  static Future<void> clearState() async {
    final prefs = await SharedPreferences.getInstance();
    await _clearPrefs(prefs);
  }

  /// Indica si el servicio está corriendo (paseo en curso en segundo plano).
  static Future<bool> isRunning() async {
    final service = FlutterBackgroundService();
    return service.isRunning();
  }
}

class WalkBackgroundState {
  final DateTime startTime;
  final double totalPausedSeconds;
  final double distanceKm;
  final double? currentPaceMinPerKm;
  final double? averageSpeedKmh;
  final bool finished;

  const WalkBackgroundState({
    required this.startTime,
    required this.totalPausedSeconds,
    required this.distanceKm,
    this.currentPaceMinPerKm,
    this.averageSpeedKmh,
    required this.finished,
  });

  int get elapsedSeconds {
    final elapsed = DateTime.now().difference(startTime).inSeconds - totalPausedSeconds.round();
    return elapsed < 0 ? 0 : elapsed;
  }
}
