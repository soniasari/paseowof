// =============================================================================
// WALK TRACK FILTER SERVICE
// =============================================================================
// Cadena de filtros para puntos GPS del paseo: precisión, velocidad máxima,
// intervalo mínimo, Kalman y deadband. La distancia se calcula con Haversine
// sobre la trayectoria ya suavizada. Solo se persisten 15 puntos al finalizar.
// =============================================================================

import 'dart:math' as math;
import '../../domain/entities/gps_point.dart';

/// Resultado de procesar un punto: si fue aceptado y distancia acumulada hasta ahora.
class FilterResult {
  final bool accepted;
  final double totalDistanceKm;
  final double? currentPaceMinPerKm;
  final double? averageSpeedKmh;

  const FilterResult({
    required this.accepted,
    required this.totalDistanceKm,
    this.currentPaceMinPerKm,
    this.averageSpeedKmh,
  });
}

/// Constantes de los filtros (negocio y GPS).
/// Política: posición cada 15 s; solo suma distancia si el tramo es >= deadband (evita ruido).
class WalkTrackFilterConfig {
  static const double maxAccuracyMeters = 20.0;
  static const double maxSpeedKmh = 20.0;
  static const int minIntervalSeconds = 10;
  /// Distancia mínima (m) entre puntos para sumar; 0 = cualquier movimiento suma (emulador y pruebas).
  static const double deadbandMeters = 0.0;
  static const double kalmanGain = 0.35;
  static const int sampleIntervalSeconds = 15;
  /// Primeros N puntos se aceptan sin comprobar precisión (emulador suele dar mala precisión).
  static const int acceptPointsWithoutAccuracy = 6;
}

class WalkTrackFilterService {
  double _totalDistanceKm = 0.0;
  final List<GpsPoint> _smoothedPoints = [];
  double? _kalmanLat;
  double? _kalmanLng;
  DateTime? _lastAcceptedTime;
  GpsPoint? _lastSmoothedPoint;

  double get totalDistanceKm => _totalDistanceKm;
  List<GpsPoint> get smoothedPoints => List.unmodifiable(_smoothedPoints);

  /// Reinicia el estado para un nuevo paseo.
  void reset() {
    _totalDistanceKm = 0.0;
    _smoothedPoints.clear();
    _kalmanLat = null;
    _kalmanLng = null;
    _lastAcceptedTime = null;
    _lastSmoothedPoint = null;
  }

  /// Procesa un nuevo punto en orden: precisión → intervalo → velocidad → Kalman → deadband.
  /// El primer punto siempre se acepta para tener referencia (aunque la precisión sea mala).
  FilterResult processPoint({
    required double latitude,
    required double longitude,
    required DateTime timestamp,
    double? accuracyMeters,
  }) {
    if (latitude.isNaN || longitude.isNaN ||
        latitude.isInfinite || longitude.isInfinite) {
      return FilterResult(accepted: false, totalDistanceKm: _totalDistanceKm);
    }
    // Evitar timestamps en el futuro (reloj del dispositivo mal configurado): usamos "ahora" como tope.
    final now = DateTime.now();
    final safeTimestamp = timestamp.isAfter(now.add(const Duration(seconds: 30)))
        ? now
        : timestamp;

    // Primeros N puntos se aceptan siempre (emulador y GPS en interior suelen dar mala precisión).
    final acceptAnyway = _smoothedPoints.length < WalkTrackFilterConfig.acceptPointsWithoutAccuracy;
    if (!acceptAnyway &&
        accuracyMeters != null &&
        accuracyMeters > WalkTrackFilterConfig.maxAccuracyMeters) {
      return FilterResult(accepted: false, totalDistanceKm: _totalDistanceKm);
    }

    if (_lastAcceptedTime != null) {
      final rawElapsed = safeTimestamp.difference(_lastAcceptedTime!).inSeconds;
      if (rawElapsed >= 0 && rawElapsed < WalkTrackFilterConfig.minIntervalSeconds) {
        return FilterResult(accepted: false, totalDistanceKm: _totalDistanceKm);
      }
    }

    final lastTime = _lastAcceptedTime ?? safeTimestamp;
    int elapsedSec = safeTimestamp.difference(lastTime).inSeconds;
    if (elapsedSec < 0) elapsedSec = WalkTrackFilterConfig.sampleIntervalSeconds;
    if (elapsedSec > 120) elapsedSec = 120;

    if (_lastSmoothedPoint != null) {
      final distKm = _haversineKm(
        _lastSmoothedPoint!.latitude,
        _lastSmoothedPoint!.longitude,
        latitude,
        longitude,
      );
      final intervalHours = elapsedSec / 3600.0;
      if (intervalHours > 0 && distKm / intervalHours > WalkTrackFilterConfig.maxSpeedKmh) {
        return FilterResult(accepted: false, totalDistanceKm: _totalDistanceKm);
      }
    }

    double smoothedLat = latitude;
    double smoothedLng = longitude;
    if (_kalmanLat != null && _kalmanLng != null) {
      smoothedLat = _kalmanLat! + WalkTrackFilterConfig.kalmanGain * (latitude - _kalmanLat!);
      smoothedLng = _kalmanLng! + WalkTrackFilterConfig.kalmanGain * (longitude - _kalmanLng!);
    }
    _kalmanLat = smoothedLat;
    _kalmanLng = smoothedLng;

    final newPoint = GpsPoint(
      latitude: smoothedLat,
      longitude: smoothedLng,
      timestamp: safeTimestamp,
      accuracy: accuracyMeters,
    );

    double distanceToAdd = 0.0;
    if (_lastSmoothedPoint != null) {
      final d = _haversineKm(
        _lastSmoothedPoint!.latitude,
        _lastSmoothedPoint!.longitude,
        smoothedLat,
        smoothedLng,
      );
      if (d * 1000.0 > WalkTrackFilterConfig.deadbandMeters) {
        distanceToAdd = d;
      }
    } else {
      distanceToAdd = 0.0;
    }

    _smoothedPoints.add(newPoint);
    _lastSmoothedPoint = newPoint;
    _lastAcceptedTime = safeTimestamp;
    _totalDistanceKm += distanceToAdd;

    double? pace;
    double? avgSpeed;
    if (distanceToAdd > 0 && elapsedSec > 0) {
      final segmentKm = distanceToAdd;
      final segmentMin = elapsedSec / 60.0;
      if (segmentKm > 0) pace = segmentMin / segmentKm;
      if (_smoothedPoints.length >= 2) {
        int totalSec = safeTimestamp.difference(_smoothedPoints.first.timestamp).inSeconds;
        if (totalSec < 0) totalSec = 0;
        if (totalSec > 86400) totalSec = 86400;
        if (totalSec > 0 && _totalDistanceKm > 0) {
          avgSpeed = _totalDistanceKm / (totalSec / 3600.0);
        }
      }
    }

    return FilterResult(
      accepted: true,
      totalDistanceKm: _totalDistanceKm,
      currentPaceMinPerKm: pace,
      averageSpeedKmh: avgSpeed,
    );
  }

  /// Devuelve exactamente 15 puntos: inicial, 13 intermedios y final.
  List<GpsPoint> select15Points() {
    if (_smoothedPoints.isEmpty) return [];
    if (_smoothedPoints.length <= 15) {
      final out = List<GpsPoint>.from(_smoothedPoints);
      while (out.length < 15) {
        out.add(_smoothedPoints.last);
      }
      return out;
    }
    final indices = <int>[0];
    for (int i = 1; i <= 13; i++) {
      final idx = (i * (_smoothedPoints.length - 1) / 14).round();
      indices.add(idx.clamp(0, _smoothedPoints.length - 1));
    }
    indices.add(_smoothedPoints.length - 1);
    return indices.map((i) => _smoothedPoints[i]).toList();
  }

  static double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.0;
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRad(lat1)) * math.cos(_toRad(lat2)) * math.sin(dLon / 2) * math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }

  static double _toRad(double deg) => deg * math.pi / 180.0;
}
