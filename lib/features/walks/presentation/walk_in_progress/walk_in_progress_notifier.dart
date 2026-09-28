// =============================================================================
// WALK IN PROGRESS NOTIFIER
// =============================================================================
// Seguimiento del paseo: flujo continuo de GPS (también con la pantalla
// apagada), lectura puntual de respaldo si el flujo no emite, y timers de UI.
// Nunca se inventan desplazamientos: si el GPS no se mueve, la distancia no crece.
// Solo depende de interfaces del dominio; el plugin de GPS y el almacenamiento
// local quedan en la capa de datos.
// =============================================================================

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/dependency_injection.dart';
import '../../domain/entities/location_fix.dart';
import '../../domain/entities/walk.dart';
import '../../domain/entities/walk_progress.dart';
import '../../domain/repositories/walk_location_repository.dart';
import '../../domain/repositories/walk_progress_repository.dart';
import '../../domain/services/walk_track_filter_service.dart';
import '../../domain/use_cases/complete_walk_with_track_use_case.dart';
import 'walk_in_progress_state.dart';

class WalkInProgressNotifier extends StateNotifier<WalkInProgressState> {
  WalkInProgressNotifier({
    required CompleteWalkWithTrackUseCase completeWalkWithTrackUseCase,
    required WalkLocationRepository locationRepository,
    required WalkProgressRepository progressRepository,
  })  : _completeWalkWithTrackUseCase = completeWalkWithTrackUseCase,
        _location = locationRepository,
        _progressRepository = progressRepository,
        super(const WalkInProgressState());

  final CompleteWalkWithTrackUseCase _completeWalkWithTrackUseCase;
  final WalkLocationRepository _location;
  final WalkProgressRepository _progressRepository;
  final WalkTrackFilterService _filter = WalkTrackFilterService();

  static const Duration _progressSaveInterval = Duration(seconds: 15);
  DateTime? _lastProgressSaveAt;
  /// Serializa guardados y borrados para que un guardado tardío no reviva un paseo ya cerrado.
  Future<void> _storageQueue = Future<void>.value();
  bool _startingTracking = false;

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
  DateTime? _streamSubscribedAt;
  bool _restartingStream = false;
  /// Android no permite volver a arrancar el servicio de ubicación desde segundo
  /// plano; con la app minimizada el flujo sigue vivo y no se reinicia.
  bool _appInForeground = true;
  /// Último fix procesado (tiempo normalizado + coordenadas); evita reprocesar la misma lectura.
  DateTime? _lastFixTimestamp;
  double? _lastFixLat;
  double? _lastFixLng;

  /// Si el flujo no emite en este tiempo, se pide una lectura puntual.
  static const Duration _streamSilenceBeforeFallback = Duration(seconds: 30);
  static const Duration _fallbackInterval = Duration(seconds: 15);

  /// Una posición cacheada solo sirve como semilla si es reciente.
  static const Duration _lastKnownMaxAge = Duration(seconds: 15);

  int get _elapsedSeconds {
    if (_startTime == null) return 0;
    final now = DateTime.now();
    final end = _pausedAt ?? now;
    final elapsed = end.difference(_startTime!).inSeconds - _totalPausedSeconds.round();
    return elapsed < 0 ? 0 : elapsed;
  }

  /// Hora del fix si es coherente con el reloj del dispositivo; si no (fix en caché
  /// antiguo, o reloj cambiado a mano), la hora actual.
  DateTime _normalizedFixTime(LocationFix fix) {
    final now = DateTime.now();
    final t = fix.timestamp;
    if (t.isAfter(now.add(const Duration(seconds: 10)))) return now;
    if (now.difference(t) > const Duration(minutes: 2)) return now;
    return t;
  }

  Future<LocationFix?> _getFreshLastKnownFix() async {
    final fix = await _location.getLastKnownFix();
    if (fix == null) return null;
    // Edad negativa = fix "del futuro" (reloj del dispositivo cambiado): no es fiable.
    final age = DateTime.now().difference(fix.timestamp);
    if (age.isNegative || age > _lastKnownMaxAge) return null;
    return fix;
  }

  /// Velocidad media coherente con tiempo y distancia mostrados: distancia / (tiempo en horas).
  double? _coherentAverageSpeedKmh(double distanceKm, int elapsedSeconds) {
    if (elapsedSeconds <= 0 || distanceKm <= 0) return null;
    final hours = elapsedSeconds / 3600.0;
    double v = distanceKm / hours;
    if (v > 15.0) v = 15.0;
    return v;
  }

  Future<void> startTracking(Walk walk, String paseadorId) async {
    if (state.hasWalk || _startingTracking) return;
    _startingTracking = true;
    try {
      WalkProgress? saved;
      try {
        saved = await _progressRepository.getFor(walkId: walk.id, paseadorId: paseadorId);
      } catch (_) {
        saved = null;
      }
      if (state.hasWalk) return;

      _filter.reset();
      _cancelled = false;
      _handlingGps = false;
      _lastStreamEventAt = null;
      _lastFixTimestamp = null;
      _lastFixLat = null;
      _lastFixLng = null;
      _lastProgressSaveAt = null;
      _startTime = DateTime.now();
      _totalPausedSeconds = 0.0;
      _pausedAt = null;
      _gpsFailureCount = 0;

      String? infoMessage;
      if (saved != null) {
        _filter.restore(totalDistanceKm: saved.distanceKm, points: saved.points);
        _startTime = saved.startTime;
        _totalPausedSeconds = saved.totalPausedSeconds;
        _pausedAt = saved.pausedAt;
        infoMessage = 'Paseo retomado: se recuperaron '
            '${(saved.distanceKm * 1000).toStringAsFixed(0)} m y ${saved.points.length} puntos.';
      }
      final paused = _pausedAt != null;

      state = WalkInProgressState(
        status: paused ? WalkInProgressStatus.paused : WalkInProgressStatus.tracking,
        walk: walk,
        paseadorId: paseadorId,
        gpsStatus: GpsStatus.capturing,
        elapsedSeconds: _elapsedSeconds,
        distanceKm: _filter.totalDistanceKm,
        gpsPointsCount: _filter.smoothedPoints.length,
        averageSpeedKmh: _coherentAverageSpeedKmh(_filter.totalDistanceKm, _elapsedSeconds),
        infoMessage: infoMessage,
      );

      _startStateTimer();
      if (!paused) _startGpsListening();
      _saveProgress(force: true);
    } finally {
      _startingTracking = false;
    }
  }

  /// La página avisa cuando la app pasa a segundo plano o vuelve.
  void onAppLifecycleChanged({required bool inForeground}) {
    _appInForeground = inForeground;
    if (!state.hasWalk || state.isFinishing) return;
    if (inForeground) {
      // Refresca tiempo y distancia al volver, sin esperar al siguiente tick.
      state = state.copyWith(
        elapsedSeconds: _elapsedSeconds,
        distanceKm: _filter.totalDistanceKm,
        gpsPointsCount: _filter.smoothedPoints.length,
      );
    } else {
      _saveProgress(force: true);
    }
  }

  /// Guarda el progreso en el teléfono como máximo cada [_progressSaveInterval],
  /// salvo [force] (pausas, errores al finalizar, salida de la pantalla).
  void _saveProgress({bool force = false}) {
    if (!state.hasWalk || state.isFinishing || _startTime == null) return;
    final now = DateTime.now();
    final last = _lastProgressSaveAt;
    if (!force && last != null && now.difference(last) < _progressSaveInterval) return;
    _lastProgressSaveAt = now;
    final progress = WalkProgress(
      walkId: state.walk!.id,
      paseadorId: state.paseadorId!,
      startTime: _startTime!,
      totalPausedSeconds: _totalPausedSeconds,
      pausedAt: _pausedAt,
      distanceKm: _filter.totalDistanceKm,
      points: _filter.smoothedPoints,
      savedAt: now,
    );
    _enqueueStorage(() => _progressRepository.save(progress));
  }

  void _clearProgress() {
    _enqueueStorage(_progressRepository.clear);
  }

  void _enqueueStorage(Future<void> Function() op) {
    _storageQueue = _storageQueue.then((_) => op()).catchError((_) {});
  }

  void _startGpsListening() {
    _gpsScheduled = true;
    _fallbackTimer?.cancel();
    _streamSubscribedAt = DateTime.now();
    _lastStreamEventAt = null;

    unawaited(_location.startUpdates(onFix: _onStreamFix, onError: _onGpsStreamError));

    _fallbackTimer = Timer.periodic(_fallbackInterval, (_) {
      unawaited(_fallbackGpsTick());
    });

    unawaited(_seedWithLastKnown());
  }

  /// El flujo lleva callado desde el último evento (o desde que se suscribió).
  bool get _streamIsSilent {
    final ref = _lastStreamEventAt ?? _streamSubscribedAt;
    if (ref == null) return true;
    return DateTime.now().difference(ref) >= _streamSilenceBeforeFallback;
  }

  /// Vuelve a suscribirse alternando proveedor. Cubre el caso en que el servicio
  /// nativo aún no estaba listo y el flujo nunca emitió. Si ya emitió, el silencio
  /// es porque el paseador está parado (filtro de distancia) y no hace falta.
  Future<void> _restartStream() async {
    if (_restartingStream || _cancelled || !_gpsScheduled || !_appInForeground) return;
    if (_lastStreamEventAt != null) return;
    _restartingStream = true;
    try {
      await _location.restartUpdates(onFix: _onStreamFix, onError: _onGpsStreamError);
      _streamSubscribedAt = DateTime.now();
      if (kDebugMode) {
        debugPrint('[GPS] stream reiniciado (${_location.providerLabel})');
      }
    } catch (_) {
    } finally {
      _restartingStream = false;
    }
  }

  Future<void> _seedWithLastKnown() async {
    if (_cancelled || !_gpsScheduled || state.isPaused) return;
    final known = await _getFreshLastKnownFix();
    if (known != null && known.isValid) {
      await _ingestFix(known, source: 'lastKnown');
    }
  }

  void _onStreamFix(LocationFix fix) {
    if (_cancelled || !_gpsScheduled || !state.hasWalk || state.isFinishing || state.isPaused) {
      return;
    }
    _lastStreamEventAt = DateTime.now();
    unawaited(_ingestFix(fix, source: 'stream'));
  }

  void _onGpsStreamError(Object error) {
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

    // Primero intentar recuperar el flujo; la lectura puntual solo cubre el hueco.
    unawaited(_restartStream());

    var fix = await _location.getCurrentFix();
    if (fix != null && !fix.isValid) fix = null;
    if (fix == null) {
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
    await _ingestFix(fix, source: 'fallback');
  }

  Future<void> _ingestFix(LocationFix fix, {required String source}) async {
    if (_cancelled || !state.hasWalk || state.isFinishing || state.isPaused) return;
    if (_handlingGps) return;
    _handlingGps = true;
    try {
      if (!fix.isValid) return;

      var fixTime = _normalizedFixTime(fix);
      final lastFix = _lastFixTimestamp;
      if (lastFix != null && !fixTime.isAfter(lastFix)) {
        // Misma lectura entregada dos veces (flujo + respaldo): no reprocesar.
        final sameCoords = _lastFixLat == fix.latitude && _lastFixLng == fix.longitude;
        if (sameCoords) return;
        // Coordenadas nuevas con tiempo que no avanza: el reloj se movió. Nunca bloquear por eso.
        fixTime = DateTime.now();
        if (!fixTime.isAfter(lastFix)) fixTime = lastFix.add(const Duration(seconds: 1));
      }
      _lastFixTimestamp = fixTime;
      _lastFixLat = fix.latitude;
      _lastFixLng = fix.longitude;

      // Timestamp del fix (no "ahora"): así la velocidad del filtro usa el tiempo real entre lecturas.
      final result = _filter.processPoint(
        latitude: fix.latitude,
        longitude: fix.longitude,
        timestamp: fixTime,
        accuracyMeters: fix.accuracy,
      );
      if (_cancelled) return;
      final debugInfo =
          '$source/${_location.providerLabel} acc=${fix.accuracy.toStringAsFixed(0)}m '
          '${result.accepted ? 'OK' : 'X:${result.rejectReason?.name}'} '
          '${(result.totalDistanceKm * 1000).toStringAsFixed(0)}m pts=${_filter.smoothedPoints.length}'
          '${_appInForeground ? '' : ' bg'}';
      if (kDebugMode) {
        debugPrint(
          '[GPS] ${fix.latitude.toStringAsFixed(6)},${fix.longitude.toStringAsFixed(6)} $debugInfo',
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
        _saveProgress();
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
    unawaited(_location.stopUpdates());
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
    _saveProgress(force: true);
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
    _saveProgress(force: true);
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
      _clearProgress();
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
        gpsPointsCount: _filter.smoothedPoints.length,
        errorMessage: e.toString(),
      );
      _saveProgress(force: true);
      _startStateTimer();
      _startGpsListening();
    }
  }

  /// Detiene el seguimiento. Con [discardProgress] (el usuario confirmó salir) se
  /// borra el progreso guardado; sin él se conserva para poder retomar el paseo.
  Future<void> cancel({bool discardProgress = true}) async {
    if (discardProgress) {
      _clearProgress();
    } else {
      _saveProgress(force: true);
    }
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
    locationRepository: ref.watch(walkLocationRepositoryProvider),
    progressRepository: ref.watch(walkProgressRepositoryProvider),
  );
});
