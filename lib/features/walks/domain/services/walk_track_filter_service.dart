// =============================================================================
// WALK TRACK FILTER SERVICE
// =============================================================================
// Cadena de filtros para puntos GPS del paseo: precisión, intervalo mínimo,
// hueco de señal, velocidad máxima, Kalman (EMA) y deadband. La distancia se
// calcula con Haversine sobre la trayectoria ya suavizada.
// Solo se persisten 15 puntos al finalizar, elegidos con Douglas-Peucker.
// Lógica de dominio pura: no depende de Flutter ni de plugins de GPS.
// =============================================================================

import 'dart:math' as math;
import '../entities/gps_point.dart';

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
  /// Último punto rechazado por velocidad: si los siguientes coinciden con él y no
  /// con el ancla, el ancla era la errónea (fix viejo o salto de posición).
  double? _lastRejectedLat;
  double? _lastRejectedLng;
  DateTime? _lastRejectedTime;

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

  /// Restaura un paseo guardado localmente (app cerrada por el sistema, reinicio, etc.).
  /// El último punto queda como ancla; si el siguiente llega tras un hueco largo,
  /// se aplica la misma regla que a cualquier corte de señal.
  void restore({required double totalDistanceKm, required List<GpsPoint> points}) {
    reset();
    if (points.isEmpty) return;
    _smoothedPoints.addAll(points);
    _totalDistanceKm = totalDistanceKm;
    final last = points.last;
    _kalmanLat = last.latitude;
    _kalmanLng = last.longitude;
    _lastSmoothedPoint = last;
    _lastRawLat = last.latitude;
    _lastRawLng = last.longitude;
    _lastAcceptedTime = last.timestamp;
  }

  /// Olvida el ancla espacial: el siguiente punto válido arranca de cero sin sumar el salto.
  void _resetAnchor() {
    _kalmanLat = null;
    _kalmanLng = null;
    _lastSmoothedPoint = null;
    _lastRawLat = null;
    _lastRawLng = null;
    _consecutiveSpeedRejects = 0;
    _clearRejected();
  }

  void _clearRejected() {
    _lastRejectedLat = null;
    _lastRejectedLng = null;
    _lastRejectedTime = null;
  }

  /// El punto nuevo es coherente (velocidad plausible) con el último rechazado.
  bool _agreesWithLastRejected(double latitude, double longitude, DateTime timestamp) {
    if (_lastRejectedLat == null || _lastRejectedLng == null || _lastRejectedTime == null) {
      return false;
    }
    final sec = timestamp.difference(_lastRejectedTime!).inSeconds;
    if (sec <= 0) return false;
    final km = _distanceKm(_lastRejectedLat!, _lastRejectedLng!, latitude, longitude);
    return km / (sec / 3600.0) <= WalkTrackFilterConfig.maxSpeedKmh;
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
          _lastRejectedLat = latitude;
          _lastRejectedLng = longitude;
          _lastRejectedTime = safeTimestamp;
          return _reject(FilterRejectReason.speedOutlier);
        }
      } else if (_consecutiveSpeedRejects > 0 &&
          _agreesWithLastRejected(latitude, longitude, safeTimestamp)) {
        // Con el paso del tiempo el salto desde el ancla ya "parece" plausible, pero el
        // punto sigue la línea de los rechazados: el ancla era la errónea. No sumar el salto.
        _resetAnchor();
      }
    }
    _consecutiveSpeedRejects = 0;
    _clearRejected();

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

  /// Haversine con el mismo radio que Geolocator.distanceBetween (WGS84 ecuatorial).
  static double _distanceKm(double lat1, double lon1, double lat2, double lon2) {
    const earthRadiusMeters = 6378137.0;
    double rad(double deg) => deg * math.pi / 180.0;
    final dLat = rad(lat2 - lat1);
    final dLon = rad(lon2 - lon1);
    final a = math.pow(math.sin(dLat / 2), 2) +
        math.pow(math.sin(dLon / 2), 2) * math.cos(rad(lat1)) * math.cos(rad(lat2));
    return earthRadiusMeters * 2 * math.asin(math.sqrt(a)) / 1000.0;
  }

  static const int savedPointsCount = 15;

  /// Devuelve exactamente [savedPointsCount] puntos: inicio, final y los intermedios
  /// que mejor conservan la forma de la ruta (esquinas y giros).
  List<GpsPoint> select15Points() {
    if (_smoothedPoints.isEmpty) return [];
    if (_smoothedPoints.length <= savedPointsCount) {
      final out = List<GpsPoint>.from(_smoothedPoints);
      while (out.length < savedPointsCount) {
        out.add(_smoothedPoints.last);
      }
      return out;
    }
    return selectKeyPoints(_smoothedPoints, savedPointsCount);
  }

  /// Douglas-Peucker con número fijo de puntos: parte del inicio y el final y va
  /// añadiendo el punto más alejado de la ruta simplificada hasta tener [count].
  /// Con los mismos puntos, el dibujo se parece mucho más al recorrido que un
  /// muestreo a intervalos fijos, que puede saltarse una esquina.
  static List<GpsPoint> selectKeyPoints(List<GpsPoint> points, int count) {
    final n = points.length;
    if (n <= count) return List<GpsPoint>.from(points);
    if (count < 2) return [points.first];

    // Proyección local a metros (equirectangular); suficiente para la escala de un paseo.
    const earthRadius = 6371000.0;
    final cosLat0 = math.cos(points.first.latitude * math.pi / 180);
    final xs = List<double>.generate(
      n,
      (i) => points[i].longitude * math.pi / 180 * cosLat0 * earthRadius,
    );
    final ys = List<double>.generate(
      n,
      (i) => points[i].latitude * math.pi / 180 * earthRadius,
    );

    final selected = <int>{0, n - 1};
    final candidates = <_DpCandidate>[_farthestInSegment(0, n - 1, xs, ys)];

    while (selected.length < count) {
      var bestPos = -1;
      for (var i = 0; i < candidates.length; i++) {
        final c = candidates[i];
        if (c.index < 0) continue;
        if (bestPos < 0 || c.distance > candidates[bestPos].distance) bestPos = i;
      }
      if (bestPos < 0) break;
      final best = candidates.removeAt(bestPos);
      selected.add(best.index);
      candidates
        ..add(_farthestInSegment(best.start, best.index, xs, ys))
        ..add(_farthestInSegment(best.index, best.end, xs, ys));
    }

    final indices = selected.toList()..sort();
    return indices.map((i) => points[i]).toList();
  }

  static _DpCandidate _farthestInSegment(int start, int end, List<double> xs, List<double> ys) {
    var bestIndex = -1;
    var bestDistance = -1.0;
    for (var i = start + 1; i < end; i++) {
      final d = _pointToSegmentMeters(xs[i], ys[i], xs[start], ys[start], xs[end], ys[end]);
      if (d > bestDistance) {
        bestDistance = d;
        bestIndex = i;
      }
    }
    return _DpCandidate(start, end, bestIndex, bestDistance);
  }

  static double _pointToSegmentMeters(
    double px, double py, double ax, double ay, double bx, double by,
  ) {
    final dx = bx - ax;
    final dy = by - ay;
    final len2 = dx * dx + dy * dy;
    // Inicio y fin iguales (paseo circular): distancia al punto de partida.
    if (len2 == 0) return math.sqrt((px - ax) * (px - ax) + (py - ay) * (py - ay));
    final t = (((px - ax) * dx + (py - ay) * dy) / len2).clamp(0.0, 1.0);
    final cx = ax + t * dx;
    final cy = ay + t * dy;
    return math.sqrt((px - cx) * (px - cx) + (py - cy) * (py - cy));
  }
}

class _DpCandidate {
  final int start;
  final int end;
  /// Índice del punto más alejado del tramo [start]-[end]; -1 si no hay intermedios.
  final int index;
  final double distance;
  const _DpCandidate(this.start, this.end, this.index, this.distance);
}
