// =============================================================================
// WALK TRACK FILTER SERVICE
// =============================================================================
// Cadena de filtros para puntos GPS del paseo: precisión, intervalo mínimo,
// hueco de señal, velocidad máxima, Kalman (EMA) y deadband. La distancia se
// calcula con Geolocator.distanceBetween sobre la trayectoria ya suavizada.
// Solo se persisten 15 puntos al finalizar.
// =============================================================================

import 'package:geolocator/geolocator.dart';
import '../../domain/entities/gps_point.dart';

enum FilterRejectReason {
  invalidCoordinates,
  accuracyTooLow,
  tooSoon,
  speedOutlier,
}

/// Resultado de procesar un punto: si fue aceptado y distancia acumulada hasta ahora.
class FilterResult {
  final bool accepted;
  final double totalDistanceKm;
  final double? currentPaceMinPerKm;
  final double? averageSpeedKmh;
  final FilterRejectReason? rejectReason;

  const FilterResult({
    required this.accepted,
    required this.totalDistanceKm,
    this.currentPaceMinPerKm,
    this.averageSpeedKmh,
    this.rejectReason,
  });
}

/// Constantes de los filtros.
/// Orden: NaN → precisión → intervalo ≥ 3 s → hueco de señal → velocidad ≤ 20 km/h → Kalman → deadband.
class WalkTrackFilterConfig {
  /// Precisión máxima aceptada una vez el GPS está "caliente".
  static const double maxAccuracyMeters = 25.0;
  /// Nunca se acepta un punto peor que esto (fixes de red/celda de cientos de metros).
  static const double hardMaxAccuracyMeters = 50.0;
  static const double maxSpeedKmh = 20.0;
  static const int minIntervalSeconds = 3;
  /// Tramos suavizados menores a esto no suman (ruido al estar parado).
  static const double deadbandMeters = 2.0;
  static const double kalmanGain = 0.55;
  static const int sampleIntervalSeconds = 5;
  /// Los primeros N puntos toleran hasta [hardMaxAccuracyMeters] (arranque en frío).
  static const int acceptPointsWithoutAccuracy = 6;
  /// Tras este hueco se reinicia el suavizado y el siguiente punto no suma distancia.
  static const int signalGapResetSeconds = 300;
  /// Si se rechazan N puntos seguidos por velocidad, el ancla estaba mal: se reinicia.
  static const int maxConsecutiveSpeedRejects = 3;
  /// Ventana para el ritmo actual (min/km) sobre los últimos tramos aceptados.
  static const int paceWindowSeconds = 60;
  static const double paceMinWindowKm = 0.02;
  static const int paceMinWindowSeconds = 15;
  static const double maxPaceMinPerKm = 60.0;
}

class _PaceSample {
  final DateTime time;
  final double cumulativeKm;
  const _PaceSample(this.time, this.cumulativeKm);
}

class WalkTrackFilterService {
  double _totalDistanceKm = 0.0;
  final List<GpsPoint> _smoothedPoints = [];
  final List<_PaceSample> _paceWindow = [];
  double? _kalmanLat;
  double? _kalmanLng;
  DateTime? _lastAcceptedTime;
  GpsPoint? _lastSmoothedPoint;
  double? _lastRawLat;
  double? _lastRawLng;
  int _consecutiveSpeedRejects = 0;

  double get totalDistanceKm => _totalDistanceKm;
  List<GpsPoint> get smoothedPoints => List.unmodifiable(_smoothedPoints);

  /// Reinicia el estado para un nuevo paseo.
  void reset() {
    _totalDistanceKm = 0.0;
    _smoothedPoints.clear();
    _paceWindow.clear();
    _resetAnchor();
    _lastAcceptedTime = null;
  }

  /// Olvida el ancla espacial: el siguiente punto válido arranca de cero sin sumar el salto.
  void _resetAnchor() {
    _kalmanLat = null;
    _kalmanLng = null;
    _lastSmoothedPoint = null;
    _lastRawLat = null;
    _lastRawLng = null;
    _consecutiveSpeedRejects = 0;
  }

  FilterResult _reject(FilterRejectReason reason) => FilterResult(
        accepted: false,
        totalDistanceKm: _totalDistanceKm,
        rejectReason: reason,
      );

  /// Procesa un nuevo punto en orden: precisión → intervalo → hueco → velocidad → Kalman → deadband.
  FilterResult processPoint({
    required double latitude,
    required double longitude,
    required DateTime timestamp,
    double? accuracyMeters,
  }) {
    if (latitude.isNaN || longitude.isNaN ||
        latitude.isInfinite || longitude.isInfinite) {
      return _reject(FilterRejectReason.invalidCoordinates);
    }
    // Evitar timestamps en el futuro (reloj del dispositivo mal configurado): usamos "ahora" como tope.
    final now = DateTime.now();
    final safeTimestamp = timestamp.isAfter(now.add(const Duration(seconds: 30)))
        ? now
        : timestamp;

    if (accuracyMeters != null) {
      if (accuracyMeters > WalkTrackFilterConfig.hardMaxAccuracyMeters) {
        return _reject(FilterRejectReason.accuracyTooLow);
      }
      final warmingUp = _smoothedPoints.length < WalkTrackFilterConfig.acceptPointsWithoutAccuracy;
      if (!warmingUp && accuracyMeters > WalkTrackFilterConfig.maxAccuracyMeters) {
        return _reject(FilterRejectReason.accuracyTooLow);
      }
    }

    // Filtro de intervalo mínimo: ≥ 3 s desde el último punto aceptado.
    if (_lastAcceptedTime != null) {
      final rawElapsed = safeTimestamp.difference(_lastAcceptedTime!).inSeconds;
      if (rawElapsed >= 0 && rawElapsed < WalkTrackFilterConfig.minIntervalSeconds) {
        return _reject(FilterRejectReason.tooSoon);
      }
    }

    // Tiempo real (sin clamp) para velocidad y recuperación.
    final lastTime = _lastAcceptedTime ?? safeTimestamp;
    int elapsedSecReal = safeTimestamp.difference(lastTime).inSeconds;
    if (elapsedSecReal < 0) {
      elapsedSecReal = WalkTrackFilterConfig.sampleIntervalSeconds;
    }

    // Corte de señal largo: no sumar el salto y no bloquear el tracking futuro.
    if (_lastAcceptedTime != null &&
        elapsedSecReal >= WalkTrackFilterConfig.signalGapResetSeconds) {
      _resetAnchor();
    }

    // Filtro de velocidad (outlier): último crudo aceptado vs nuevo crudo, con tiempo real.
    // Se compara contra el crudo y no contra el suavizado para que el retraso del EMA no infle la velocidad.
    if (_lastRawLat != null && _lastRawLng != null) {
      final distKm = _distanceKm(_lastRawLat!, _lastRawLng!, latitude, longitude);
      final intervalHours = elapsedSecReal / 3600.0;
      if (intervalHours > 0 && distKm / intervalHours > WalkTrackFilterConfig.maxSpeedKmh) {
        _consecutiveSpeedRejects++;
        if (_consecutiveSpeedRejects >= WalkTrackFilterConfig.maxConsecutiveSpeedRejects) {
          // El ancla era el outlier (p. ej. primer fix malo): reanclar en este punto sin sumar el salto.
          _resetAnchor();
        } else {
          return _reject(FilterRejectReason.speedOutlier);
        }
      }
    }
    _consecutiveSpeedRejects = 0;

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

    // Deadband: entre último suavizado y nuevo suavizado; solo suma si el tramo supera el umbral.
    double distanceToAdd = 0.0;
    if (_lastSmoothedPoint != null) {
      final d = _distanceKm(
        _lastSmoothedPoint!.latitude,
        _lastSmoothedPoint!.longitude,
        smoothedLat,
        smoothedLng,
      );
      if (d * 1000.0 > WalkTrackFilterConfig.deadbandMeters) {
        distanceToAdd = d;
      }
    }

    _smoothedPoints.add(newPoint);
    _lastSmoothedPoint = newPoint;
    _lastRawLat = latitude;
    _lastRawLng = longitude;
    _lastAcceptedTime = safeTimestamp;
    _totalDistanceKm += distanceToAdd;

    return FilterResult(
      accepted: true,
      totalDistanceKm: _totalDistanceKm,
      currentPaceMinPerKm: _updatePace(safeTimestamp),
      averageSpeedKmh: null,
    );
  }

  /// Ritmo sobre una ventana móvil de los últimos [paceWindowSeconds]; evita saltos por tramos cortos.
  double? _updatePace(DateTime now) {
    _paceWindow.add(_PaceSample(now, _totalDistanceKm));
    final cutoff = now.subtract(const Duration(seconds: WalkTrackFilterConfig.paceWindowSeconds));
    while (_paceWindow.length > 1 && _paceWindow.first.time.isBefore(cutoff)) {
      _paceWindow.removeAt(0);
    }
    if (_paceWindow.length < 2) return null;
    final first = _paceWindow.first;
    final km = _totalDistanceKm - first.cumulativeKm;
    final sec = now.difference(first.time).inSeconds;
    if (km < WalkTrackFilterConfig.paceMinWindowKm || sec < WalkTrackFilterConfig.paceMinWindowSeconds) {
      return null;
    }
    final pace = (sec / 60.0) / km;
    return pace > WalkTrackFilterConfig.maxPaceMinPerKm ? WalkTrackFilterConfig.maxPaceMinPerKm : pace;
  }

  /// Distancia en km vía Geolocator (Haversine en metros).
  static double _distanceKm(double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2) / 1000.0;
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
}
