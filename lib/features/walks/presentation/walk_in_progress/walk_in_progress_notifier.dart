// =============================================================================
// WALK IN PROGRESS NOTIFIER
// =============================================================================
// Seguimiento del paseo solo en primer plano: GPS cada 15 s en el main isolate,
// filtro de puntos y actualización de estado. Sin servicio en segundo plano.
// =============================================================================

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../core/di/dependency_injection.dart';
import '../../data/services/walk_track_filter_service.dart';
import '../../domain/entities/walk.dart';
import '../../domain/use_cases/complete_walk_with_track_use_case.dart';
import 'walk_in_progress_state.dart';

class WalkInProgressNotifier extends StateNotifier<WalkInProgressState> {
  WalkInProgressNotifier({
    required CompleteWalkWithTrackUseCase completeWalkWithTrackUseCase,
  })  : _completeWalkWithTrackUseCase = completeWalkWithTrackUseCase,
        super(const WalkInProgressState());

  final CompleteWalkWithTrackUseCase _completeWalkWithTrackUseCase;
  final WalkTrackFilterService _filter = WalkTrackFilterService();

  Timer? _stateTimer;
  Timer? _gpsTimer;
  bool _gpsScheduled = true;
  bool _cancelled = false;
  int _gpsFailureCount = 0;
  DateTime? _startTime;
  double _totalPausedSeconds = 0.0;
  DateTime? _pausedAt;
  /// Última posición recibida (para detectar emulador sin movimiento).
  Position? _lastPosition;
  /// Pequeño desplazamiento acumulado cuando la posición no cambia (emulador fijo).
  double _emulatorDriftLat = 0.0;
  double _emulatorDriftLng = 0.0;

  int get _elapsedSeconds {
    if (_startTime == null) return 0;
    final now = DateTime.now();
    final end = _pausedAt ?? now;
    final elapsed = end.difference(_startTime!).inSeconds - _totalPausedSeconds.round();
    return elapsed < 0 ? 0 : elapsed;
  }

  /// Timeout duro para no bloquear si el plugin ignora timeLimit (evita que la app se cuelgue).
  static const Duration _gpsHardTimeout = Duration(seconds: 20);

  Future<Position?> _getPositionWithTimeout() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 15),
        ),
      ).timeout(_gpsHardTimeout);
      return position;
    } catch (_) {
      return null;
    }
  }

  /// Inicia el seguimiento en primer plano: timer 1 s para tiempo y timer 15 s para GPS.
  Future<void> startTracking(Walk walk, String paseadorId) async {
    if (state.hasWalk) return;

    _filter.reset();
    _cancelled = false;
    _lastPosition = null;
    _emulatorDriftLat = 0.0;
    _emulatorDriftLng = 0.0;
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
    _fetchGpsOnceThenSchedule();
  }

  void _fetchGpsOnceThenSchedule() async {
    try {
      if (_cancelled || !state.hasWalk || state.isFinishing || state.isPaused) return;
      final position = await _getPositionWithTimeout();
      if (_cancelled) return;
      if (position == null) {
        _gpsFailureCount++;
        return;
      }
      if (!state.hasWalk || state.isFinishing || state.isPaused) return;
      double lat = position.latitude;
      double lng = position.longitude;
      final sameAsLast = _lastPosition != null &&
          _lastPosition!.latitude == position.latitude &&
          _lastPosition!.longitude == position.longitude;
      if (sameAsLast) {
        _emulatorDriftLat += 0.00002;
        lat = position.latitude + _emulatorDriftLat;
        lng = position.longitude + _emulatorDriftLng;
      } else {
        _emulatorDriftLat = 0.0;
        _emulatorDriftLng = 0.0;
      }
      _lastPosition = position;
      final result = _filter.processPoint(
        latitude: lat,
        longitude: lng,
        timestamp: DateTime.now(),
        accuracyMeters: position.accuracy,
      );
      if (_cancelled) return;
      if (result.accepted) {
        _gpsFailureCount = 0;
        state = state.copyWith(
          distanceKm: result.totalDistanceKm,
          currentPaceMinPerKm: result.currentPaceMinPerKm,
          averageSpeedKmh: result.averageSpeedKmh,
          gpsStatus: GpsStatus.capturing,
          gpsPointsCount: _filter.smoothedPoints.length,
        );
      }
    } catch (_) {
      if (!_cancelled) _gpsFailureCount++;
    } finally {
      if (!_cancelled) _startGpsTimer();
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
        if (state.elapsedSeconds == elapsed && state.distanceKm == dist && state.gpsPointsCount == pointsCount) return;
        state = state.copyWith(
          elapsedSeconds: elapsed,
          distanceKm: dist,
          gpsPointsCount: pointsCount,
        );
      } catch (_) {}
    });
  }

  void _startGpsTimer() {
    _gpsTimer?.cancel();
    _gpsScheduled = true;
    void scheduleNext() {
      if (!_gpsScheduled) return;
      _gpsTimer = Timer(const Duration(seconds: 15), () async {
        try {
          if (_cancelled || !_gpsScheduled || !state.hasWalk || state.isFinishing || state.isPaused) {
            return;
          }
          final position = await _getPositionWithTimeout();
          if (_cancelled) return;
          if (position == null) {
            _gpsFailureCount++;
            try {
              if (state.hasWalk && !state.isFinishing && _gpsFailureCount >= 3) {
                state = state.copyWith(gpsStatus: GpsStatus.error);
              }
            } catch (_) {}
            return;
          }
          if (!state.hasWalk || state.isFinishing || state.isPaused) return;
          double lat = position.latitude;
          double lng = position.longitude;
          final sameAsLast = _lastPosition != null &&
              _lastPosition!.latitude == position.latitude &&
              _lastPosition!.longitude == position.longitude;
          if (sameAsLast) {
            _emulatorDriftLat += 0.00002;
            lat = position.latitude + _emulatorDriftLat;
            lng = position.longitude + _emulatorDriftLng;
          } else {
            _emulatorDriftLat = 0.0;
            _emulatorDriftLng = 0.0;
          }
          _lastPosition = position;
          final result = _filter.processPoint(
            latitude: lat,
            longitude: lng,
            timestamp: DateTime.now(),
            accuracyMeters: position.accuracy,
          );
          if (_cancelled) return;
          if (result.accepted) {
            _gpsFailureCount = 0;
            state = state.copyWith(
              distanceKm: result.totalDistanceKm,
              currentPaceMinPerKm: result.currentPaceMinPerKm,
              averageSpeedKmh: result.averageSpeedKmh,
              gpsStatus: GpsStatus.capturing,
              gpsPointsCount: _filter.smoothedPoints.length,
            );
          }
        } catch (_) {
          if (!_cancelled) {
            _gpsFailureCount++;
            try {
              if (state.hasWalk && !state.isFinishing && _gpsFailureCount >= 3) {
                state = state.copyWith(gpsStatus: GpsStatus.error);
              }
            } catch (_) {}
          }
        } finally {
          scheduleNext();
        }
      });
    }
    scheduleNext();
  }

  void _stopTimers() {
    _cancelled = true;
    _gpsScheduled = false;
    _stateTimer?.cancel();
    _stateTimer = null;
    _gpsTimer?.cancel();
    _gpsTimer = null;
  }

  void pause() {
    if (!state.hasWalk || state.isPaused) return;
    _pausedAt = DateTime.now();
    _gpsTimer?.cancel();
    _gpsTimer = null;
    state = state.copyWith(status: WalkInProgressStatus.paused);
  }

  Future<void> resume() async {
    if (!state.hasWalk || !state.isPaused) return;
    if (_pausedAt != null) {
      _totalPausedSeconds += DateTime.now().difference(_pausedAt!).inSeconds;
      _pausedAt = null;
    }
    _startGpsTimer();
    state = state.copyWith(status: WalkInProgressStatus.tracking);
  }

  /// Finaliza el paseo: obtiene los 15 puntos del filtro y sube a Firestore.
  Future<void> finishWalk() async {
    if (!state.hasWalk || state.isFinishing) return;

    state = state.copyWith(status: WalkInProgressStatus.finishing);
    _stopTimers();

    final walk = state.walk!;
    final paseadorId = state.paseadorId!;
    final distanceKm = _filter.totalDistanceKm;

    final points = _filter.select15Points();

    if (points.length < 15) {
      _cancelled = false;
      _gpsScheduled = true;
      state = state.copyWith(
        status: WalkInProgressStatus.tracking,
        errorMessage: 'Se necesitan al menos 15 puntos para guardar la ruta.',
      );
      _startStateTimer();
      _fetchGpsOnceThenSchedule();
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
      _gpsScheduled = true;
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
      _fetchGpsOnceThenSchedule();
    }
  }

  /// Cancela el seguimiento sin guardar.
  Future<void> cancel() async {
    _stopTimers();
    try {
      state = const WalkInProgressState();
    } catch (_) {}
  }
}

/// Sin autoDispose para que dispose() de la página pueda cancelar sin provocar crash.
final walkInProgressProvider =
    StateNotifierProvider<WalkInProgressNotifier, WalkInProgressState>((ref) {
  return WalkInProgressNotifier(
    completeWalkWithTrackUseCase: ref.watch(completeWalkWithTrackUseCaseProvider),
  );
});
