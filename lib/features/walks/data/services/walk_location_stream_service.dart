// =============================================================================
// WALK LOCATION STREAM SERVICE
// =============================================================================
// Un único stream nativo de GPS (no getCurrentPosition en bucle). Intervalo
// ~5 s + distanceFilter 5 m: caminando (~1.4 m/s) llega un punto cada ~5 s;
// parado, el proveedor no emite y no se acumula ruido. La suscripción se
// cancela al pausar, finalizar o dispose.
//
// En Android, si el servicio interno de geolocator aún no está enlazado, el
// stream no emite nada ni lanza error. Por eso [restart] permite volver a
// suscribirse alternando entre FusedLocationProvider y LocationManager (GPS
// puro, que en emulador recibe la ruta simulada directamente).
// =============================================================================

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

const Duration walkLocationInterval = Duration(seconds: 5);
const int walkDistanceFilterMeters = 5;
const Duration walkMinEmitInterval = Duration(seconds: 3);
/// Si el stream calla más de esto, se pide una posición puntual (con timeout).
const Duration walkFallbackInterval = Duration(seconds: 15);

/// Ajustes de GPS para el paseo: intervalo y filtro de distancia para limitar eventos.
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
      );
    case TargetPlatform.iOS:
      return AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: walkDistanceFilterMeters,
        activityType: ActivityType.fitness,
        pauseLocationUpdatesAutomatically: false,
      );
    default:
      return const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: walkDistanceFilterMeters,
      );
  }
}

/// Servicio que entrega posiciones del GPS con throttling.
/// [listen] cancela cualquier suscripción previa; [cancel] hay que llamarlo al salir.
class WalkLocationStreamService {
  StreamSubscription<Position>? _subscription;
  DateTime? _lastEmittedAt;
  bool _usingLocationManager = false;

  /// true si la suscripción actual usa LocationManager (GPS puro) en Android.
  bool get usingLocationManager => _usingLocationManager;

  Stream<Position> getPositionStream({bool forceLocationManager = false}) {
    return Geolocator.getPositionStream(
      locationSettings: walkTrackingLocationSettings(forceLocationManager: forceLocationManager),
    );
  }

  /// Escucha el stream, aplica debounce mínimo y ejecuta [onPosition].
  /// [onError] no cierra la suscripción (cancelOnError: false).
  Future<StreamSubscription<Position>> listen(
    void Function(Position) onPosition, {
    Function(dynamic)? onError,
    bool forceLocationManager = false,
  }) async {
    // geolocator cachea el stream nativo hasta que el último oyente cancela;
    // esperar el cancel garantiza que los nuevos ajustes se apliquen.
    await cancel();
    _usingLocationManager = forceLocationManager;
    _subscription = getPositionStream(forceLocationManager: forceLocationManager).listen(
      (position) {
        final now = DateTime.now();
        final last = _lastEmittedAt;
        if (last != null && now.difference(last) < walkMinEmitInterval) {
          return;
        }
        _lastEmittedAt = now;
        onPosition(position);
      },
      onError: onError,
      cancelOnError: false,
    );
    return _subscription!;
  }

  /// Vuelve a suscribirse alternando el proveedor (fused ↔ LocationManager).
  Future<void> restart(
    void Function(Position) onPosition, {
    Function(dynamic)? onError,
  }) {
    return listen(
      onPosition,
      onError: onError,
      forceLocationManager: !_usingLocationManager,
    );
  }

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
}
