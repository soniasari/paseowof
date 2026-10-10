// =============================================================================
// WALK LOCATION DATA SOURCE
// =============================================================================
// Único punto de la app que habla con el plugin geolocator durante el paseo.
//
// Un solo stream nativo de GPS (no getCurrentPosition en bucle). Intervalo
// ~5 s + distanceFilter 5 m: caminando (~1.4 m/s) llega un punto cada ~5 s;
// parado, el proveedor no emite y no se acumula ruido.
//
// Segundo plano: en Android el stream corre como servicio en primer plano de
// geolocator (notificación fija "Paseo en curso"), en el mismo motor Flutter,
// así que sigue recibiendo puntos con la pantalla apagada. En iOS se activan
// las actualizaciones en segundo plano con el indicador azul del sistema.
//
// Si el servicio interno de geolocator aún no está enlazado, el stream no
// emite nada ni lanza error. Por eso [restart] permite volver a suscribirse
// alternando entre FusedLocationProvider y LocationManager (GPS puro).
// =============================================================================

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

const Duration walkLocationInterval = Duration(seconds: 5);
const int walkDistanceFilterMeters = 5;
const Duration walkMinEmitInterval = Duration(seconds: 3);

const ForegroundNotificationConfig _walkForegroundNotification = ForegroundNotificationConfig(
  notificationTitle: 'Paseo en curso',
  notificationText: 'PaseoWoow está registrando la ruta del paseo.',
  notificationChannelName: 'Paseo en curso',
  // Sin wake lock el sistema duerme la CPU y los puntos llegan en bloque al despertar.
  enableWakeLock: true,
  setOngoing: true,
);

/// Ajustes del stream del paseo, con seguimiento en segundo plano.
LocationSettings walkTrackingLocationSettings({bool forceLocationManager = false}) {
  if (kIsWeb) {
    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: walkDistanceFilterMeters,
    );
  }
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: walkDistanceFilterMeters,
        intervalDuration: walkLocationInterval,
        forceLocationManager: forceLocationManager,
        foregroundNotificationConfig: _walkForegroundNotification,
      );
    case TargetPlatform.iOS:
      return AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: walkDistanceFilterMeters,
        activityType: ActivityType.fitness,
        pauseLocationUpdatesAutomatically: false,
        allowBackgroundLocationUpdates: true,
        showBackgroundLocationIndicator: true,
      );
    default:
      return const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: walkDistanceFilterMeters,
      );
  }
}

abstract class WalkLocationDataSource {
  /// true si la suscripción actual usa LocationManager (GPS puro) en Android.
  bool get usingLocationManager;

  Future<void> listen(
    void Function(Position position) onPosition, {
    void Function(Object error)? onError,
    bool forceLocationManager = false,
  });

  /// Vuelve a suscribirse alternando el proveedor (fused ↔ LocationManager).
  Future<void> restart(
    void Function(Position position) onPosition, {
    void Function(Object error)? onError,
  });

  Future<void> cancel();

  Future<Position?> getCurrentPosition();

  Future<Position?> getLastKnownPosition();
}

class WalkLocationDataSourceImpl implements WalkLocationDataSource {
  StreamSubscription<Position>? _subscription;
  DateTime? _lastEmittedAt;
  bool _usingLocationManager = false;

  /// Tope duro: getCurrentPosition en Android puede no responder nunca si no hay fix.
  static const Duration _currentPositionHardTimeout = Duration(seconds: 10);

  @override
  bool get usingLocationManager => _usingLocationManager;

  @override
  Future<void> listen(
    void Function(Position position) onPosition, {
    void Function(Object error)? onError,
    bool forceLocationManager = false,
  }) async {
    // geolocator cachea el stream nativo hasta que el último oyente cancela;
    // esperar el cancel garantiza que los nuevos ajustes se apliquen.
    await cancel();
    _usingLocationManager = forceLocationManager;
    _subscription = Geolocator.getPositionStream(
      locationSettings: walkTrackingLocationSettings(forceLocationManager: forceLocationManager),
    ).listen(
      (position) {
        final now = DateTime.now();
        final last = _lastEmittedAt;
        if (last != null && now.difference(last) < walkMinEmitInterval) return;
        _lastEmittedAt = now;
        onPosition(position);
      },
      onError: (Object error) => onError?.call(error),
      cancelOnError: false,
    );
  }

  @override
  Future<void> restart(
    void Function(Position position) onPosition, {
    void Function(Object error)? onError,
  }) {
    return listen(onPosition, onError: onError, forceLocationManager: !_usingLocationManager);
  }

  @override
  Future<void> cancel() async {
    final sub = _subscription;
    _subscription = null;
    _lastEmittedAt = null;
    if (sub != null) {
      try {
        await sub.cancel();
      } catch (_) {}
    }
  }

  /// En Android se fuerza LocationManager (GPS puro): el proveedor "fused"
  /// responde con su caché y devolvería la misma posición aunque el dispositivo se mueva.
  @override
  Future<Position?> getCurrentPosition() async {
    try {
      final LocationSettings settings = !kIsWeb && defaultTargetPlatform == TargetPlatform.android
          ? AndroidSettings(
              accuracy: LocationAccuracy.high,
              forceLocationManager: true,
              timeLimit: const Duration(seconds: 8),
            )
          : const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 8),
            );
      return await Geolocator.getCurrentPosition(locationSettings: settings)
          .timeout(_currentPositionHardTimeout);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Position?> getLastKnownPosition() async {
    try {
      return await Geolocator.getLastKnownPosition();
    } catch (_) {
      return null;
    }
  }
}
