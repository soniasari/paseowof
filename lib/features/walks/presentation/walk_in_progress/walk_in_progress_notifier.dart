// =============================================================================
// WALK IN PROGRESS NOTIFIER
// =============================================================================
// Seguimiento del paseo: un StreamSubscription de GPS (intervalo ~5 s +
// distanceFilter), fallback acotado si el stream no emite, y timers de UI.
// Nunca se inventan desplazamientos: si el GPS no se mueve, la distancia no crece.
// =============================================================================

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../core/di/dependency_injection.dart';
import '../../data/services/walk_location_stream_service.dart';
import '../../data/services/walk_track_filter_service.dart';
import '../../domain/entities/walk.dart';
import '../../domain/use_cases/complete_walk_with_track_use_case.dart';
import 'walk_in_progress_state.dart';

class WalkInProgressNotifier extends StateNotifier<WalkInProgressState> {
  WalkInProgressNotifier({
    required CompleteWalkWithTrackUseCase completeWalkWithTrackUseCase,
    WalkLocationStreamService? locationStreamService,
  })  : _completeWalkWithTrackUseCase = completeWalkWithTrackUseCase,
        _locationStream = locationStreamService ?? WalkLocationStreamService(),
        super(const WalkInProgressState());

  final CompleteWalkWithTrackUseCase _completeWalkWithTrackUseCase;
  final WalkLocationStreamService _locationStream;
  final WalkTrackFilterService _filter = WalkTrackFilterService();

  Timer? _stateTimer;
  Timer? _fallbackTimer;
  bool _gpsScheduled = true;
  bool _cancelled = false;
  bool _handlingGps = false;
  int _gpsFailureCount = 0;
  DateTime? _startTime;
  double _totalPausedSeconds = 0.0;
  DateTime? _pausedAt;
  DateTime? _lastStreamEventAt;
  /// Timestamp del último fix procesado; evita reprocesar la misma lectura.
  DateTime? _lastFixTimestamp;

  int get _elapsedSeconds {
    if (_startTime == null) return 0;
    final now = DateTime.now();
    final end = _pausedAt ?? now;
    final elapsed = end.difference(_startTime!).inSeconds - _totalPausedSeconds.round();
    return elapsed < 0 ? 0 : elapsed;
  }

  /// Timeout corto: getCurrentPosition en Android puede bloquear el isolate si no hay fix.
  static const Duration _gpsHardTimeout = Duration(seconds: 10);

  /// Si el stream no emite en este tiempo, un fallback acotado (GPS frío).
  static const Duration _streamSilenceBeforeFallback = Duration(seconds: 30);

  /// Una posición cacheada solo sirve como semilla si es reciente.
  static const Duration _lastKnownMaxAge = Duration(seconds: 15);

  /// Fallback con precisión alta. En Android se fuerza LocationManager (GPS puro):
  /// el proveedor "fused" responde con su caché y devolvería la misma posición en
  /// cada tick aunque el dispositivo se esté moviendo.
  Future<Position?> _getPositionWithTimeout() async {
    try {
      final LocationSettings settings = defaultTargetPlatform == TargetPlatform.android && !kIsWeb
          ? AndroidSettings(
              accuracy: LocationAccuracy.high,
              forceLocationManager: true,
              timeLimit: const Duration(seconds: 8),
            )
          : const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 8),
            );
      final position = await Geolocator.getCurrentPosition(locationSettings: settings)
          .timeout(_gpsHardTimeout);
      return position;
    } catch (_) {
      return null;
    }
  }

  Future<Position?> _getFreshLastKnownPosition() async {
    try {
      final p = await Geolocator.getLastKnownPosition();
      if (p == null) return null;
      if (DateTime.now().difference(p.timestamp) > _lastKnownMaxAge) return null;
      return p;
    } catch (_) {
      return null;
    }
  }

  /// Velocidad media coherente con tiempo y distancia mostrados: distancia / (tiempo en horas).
  double? _coherentAverageSpeedKmh(double distanceKm, int elapsedSeconds) {
    if (elapsedSeconds <= 0 || distanceKm <= 0) return null;
    final hours = elapsedSeconds / 3600.0;
    double v = distanceKm / hours;
    if (v > 15.0) v = 15.0;
    return v;
  }

  bool _isValidPosition(Position p) {
    final lat = p.latitude;
    final lng = p.longitude;
    return !lat.isNaN && !lng.isNaN && !lat.isInfinite && !lng.isInfinite;
  }

  Future<void> startTracking(Walk walk, String paseadorId) async {
    if (state.hasWalk) return;

    _filter.reset();
    _cancelled = false;
    _handlingGps = false;
    _lastStreamEventAt = null;
    _lastFixTimestamp = null;
    _startTime = DateTime.now();
    _totalPausedSeconds = 0.0;
    _pausedAt = null;
    _gpsFailureCount = 0;

    state = WalkInProgressState(
      status: WalkInProgressStatus.tracking,
      walk: walk,
      paseadorId: paseadorId,
      gpsStatus: GpsStatus.capturing,
    );

    _startStateTimer();
    _startGpsListening();
  }

  void _startGpsListening() {
    _gpsScheduled = true;
    _fallbackTimer?.cancel();
    _streamSubscribedAt = DateTime.now();
    _lastStreamEventAt = null;

    unawaited(_locationStream.listen(
      _onStreamPosition,
      onError: _onGpsStreamError,
    ));

    _fallbackTimer = Timer.periodic(walkFallbackInterval, (_) {
      unawaited(_fallbackGpsTick());
    });

    unawaited(_seedWithLastKnown());
  }

  DateTime? _streamSubscribedAt;
  bool _restartingStream = false;

  /// El stream lleva callado desde el último evento (o desde que se suscribió).
  bool get _streamIsSilent {
    final ref = _lastStreamEventAt ?? _streamSubscribedAt;
    if (ref == null) return true;
    return DateTime.now().difference(ref) >= _streamSilenceBeforeFallback;
  }

  /// Vuelve a suscribirse alternando proveedor. Cubre el caso en que el servicio
  /// nativo de geolocator no estaba listo y el stream quedó mudo sin error.
  Future<void> _restartStream() async {
    if (_restartingStream || _cancelled || !_gpsScheduled) return;
    _restartingStream = true;
    try {
      await _locationStream.restart(
        _onStreamPosition,
        onError: _onGpsStreamError,
      );
      _streamSubscribedAt = DateTime.now();
      _lastStreamEventAt = null;
      if (kDebugMode) {
        debugPrint('[GPS] stream reiniciado (locationManager=${_locationStream.usingLocationManager})');
      }
    } catch (_) {
    } finally {
      _restartingStream = false;
    }
  }

  Future<void> _seedWithLastKnown() async {
    if (_cancelled || !_gpsScheduled || state.isPaused) return;
    final known = await _getFreshLastKnownPosition();
    if (known != null && _isValidPosition(known)) {
      await _ingestPosition(known);
    }
  }

  void _onStreamPosition(Position position) {
    if (_cancelled || !_gpsScheduled || !state.hasWalk || state.isFinishing || state.isPaused) {
      return;
    }
    _lastStreamEventAt = DateTime.now();
    unawaited(_ingestPosition(position, source: 'stream'));
  }

  void _onGpsStreamError(dynamic error) {
    if (_cancelled || !state.hasWalk || state.isFinishing) return;
    _gpsFailureCount++;
    if (_gpsFailureCount >= 3) {
      try {
        state = state.copyWith(gpsStatus: GpsStatus.error);
      } catch (_) {}
    }
  }

  Future<void> _fallbackGpsTick() async {
    if (_cancelled || !_gpsScheduled || !state.hasWalk || state.isFinishing || state.isPaused) {
      return;
    }
    if (!_streamIsSilent) return;
    if (_handlingGps) return;

    // Primero intentar recuperar el stream; el fallback puntual solo cubre el hueco.
    unawaited(_restartStream());

    var position = await _getPositionWithTimeout();
    if (position != null && !_isValidPosition(position)) position = null;
    if (position == null) {
      _gpsFailureCount++;
      if (_gpsFailureCount >= 3 && state.hasWalk && !state.isFinishing) {
        try {
          state = state.copyWith(
            gpsStatus: GpsStatus.error,
            gpsDebugInfo: 'fallback sin respuesta (${_gpsFailureCount}x)',
          );
        } catch (_) {}
      }
      return;
    }
    await _ingestPosition(position, source: 'fallback');
  }

  Future<void> _ingestPosition(Position position, {String source = 'stream'}) async {
    if (_cancelled || !state.hasWalk || state.isFinishing || state.isPaused) return;
    if (_handlingGps) return;
    _handlingGps = true;
    try {
      if (!_isValidPosition(position)) return;

      // Misma lectura entregada dos veces (stream + fallback): no reprocesar.
      final fixTime = position.timestamp;
      if (_lastFixTimestamp != null && !fixTime.isAfter(_lastFixTimestamp!)) return;
      _lastFixTimestamp = fixTime;

      // Timestamp del fix (no "ahora"): así la velocidad del filtro usa el tiempo real entre lecturas.
      final result = _filter.processPoint(
        latitude: position.latitude,
        longitude: position.longitude,
        timestamp: fixTime,
        accuracyMeters: position.accuracy,
      );
      if (_cancelled) return;
      final provider = _locationStream.usingLocationManager ? 'LM' : 'fused';
      final debugInfo =
          '$source/$provider acc=${position.accuracy.toStringAsFixed(0)}m '
          '${result.accepted ? 'OK' : 'X:${result.rejectReason?.name}'} '
          '${(result.totalDistanceKm * 1000).toStringAsFixed(0)}m pts=${_filter.smoothedPoints.length}';
      if (kDebugMode) {
        debugPrint(
          '[GPS] ${position.latitude.toStringAsFixed(6)},${position.longitude.toStringAsFixed(6)} $debugInfo',
        );
      }
      if (result.accepted) {
        _gpsFailureCount = 0;
        state = state.copyWith(
          distanceKm: result.totalDistanceKm,
          currentPaceMinPerKm: result.currentPaceMinPerKm,
          averageSpeedKmh: _coherentAverageSpeedKmh(result.totalDistanceKm, _elapsedSeconds),
          gpsStatus: GpsStatus.capturing,
          gpsPointsCount: _filter.smoothedPoints.length,
          gpsDebugInfo: debugInfo,
        );
      } else {
        state = state.copyWith(gpsDebugInfo: debugInfo);
      }
    } catch (_) {
      if (!_cancelled) _gpsFailureCount++;
    } finally {
      _handlingGps = false;
    }
  }

  void _startStateTimer() {
    _stateTimer?.cancel();
    _stateTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      try {
        if (_cancelled || !state.hasWalk || state.isFinishing) return;
        final elapsed = _elapsedSeconds;
        final dist = _filter.totalDistanceKm;
        final pointsCount = _filter.smoothedPoints.length;
        if (state.elapsedSeconds == elapsed && state.distanceKm == dist && state.gpsPointsCount == pointsCount) {
          return;
        }
        state = state.copyWith(
          elapsedSeconds: elapsed,
          distanceKm: dist,
          averageSpeedKmh: _coherentAverageSpeedKmh(dist, elapsed),
          gpsPointsCount: pointsCount,
        );
      } catch (_) {}
    });
  }

  void _stopGpsListening() {
    _gpsScheduled = false;
    unawaited(_locationStream.cancel());
    _fallbackTimer?.cancel();
    _fallbackTimer = null;
  }

  void _stopTimers() {
    _cancelled = true;
    _stopGpsListening();
    _stateTimer?.cancel();
    _stateTimer = null;
  }

  void pause() {
    if (!state.hasWalk || state.isPaused) return;
    _pausedAt = DateTime.now();
    _stopGpsListening();
    state = state.copyWith(status: WalkInProgressStatus.paused);
  }

  Future<void> resume() async {
    if (!state.hasWalk || !state.isPaused) return;
    if (_pausedAt != null) {
      _totalPausedSeconds += DateTime.now().difference(_pausedAt!).inSeconds;
      _pausedAt = null;
    }
    _cancelled = false;
    _startGpsListening();
    state = state.copyWith(status: WalkInProgressStatus.tracking);
  }

  /// Finaliza el paseo: obtiene los 15 puntos del filtro y sube a Firestore.
  /// Requiere al menos 15 puntos GPS reales (no se rellena con duplicados).
  Future<void> finishWalk() async {
    if (!state.hasWalk || state.isFinishing) return;

    final pointsCount = _filter.smoothedPoints.length;
    if (pointsCount < 15) {
      state = state.copyWith(
        errorMessage: 'Se necesitan al menos 15 puntos para finalizar el paseo (actual: $pointsCount/15). Continúa el recorrido un poco más.',
      );
      return;
    }

    state = state.copyWith(status: WalkInProgressStatus.finishing);
    _stopTimers();

    final walk = state.walk!;
    final paseadorId = state.paseadorId!;
    final distanceKm = _filter.totalDistanceKm;

    final points = _filter.select15Points();
    if (points.length < 15) {
      _cancelled = false;
      state = state.copyWith(
        status: WalkInProgressStatus.tracking,
        errorMessage: 'Se necesitan al menos 15 puntos para guardar la ruta.',
      );
      _startStateTimer();
      _startGpsListening();
      return;
    }

    try {
      await _completeWalkWithTrackUseCase.execute(
        paseadorId: paseadorId,
        walkId: walk.id,
        points: points,
        distanciaKm: distanceKm,
      );
      state = const WalkInProgressState();
    } catch (e) {
      _cancelled = false;
      state = WalkInProgressState(
        status: WalkInProgressStatus.tracking,
        walk: walk,
        paseadorId: paseadorId,
        elapsedSeconds: state.elapsedSeconds,
        distanceKm: state.distanceKm,
        gpsStatus: state.gpsStatus,
        errorMessage: e.toString(),
      );
      _startStateTimer();
      _startGpsListening();
    }
  }

  Future<void> cancel() async {
    _stopTimers();
    try {
      state = const WalkInProgressState();
    } catch (_) {}
  }

  @override
  void dispose() {
    _stopTimers();
    super.dispose();
  }
}

/// Sin autoDispose para que dispose() de la página pueda cancelar sin provocar crash.
final walkInProgressProvider =
    StateNotifierProvider<WalkInProgressNotifier, WalkInProgressState>((ref) {
  return WalkInProgressNotifier(
    completeWalkWithTrackUseCase: ref.watch(completeWalkWithTrackUseCaseProvider),
    locationStreamService: ref.watch(walkLocationStreamServiceProvider),
  );
});
