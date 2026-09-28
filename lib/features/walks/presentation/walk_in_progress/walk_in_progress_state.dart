// =============================================================================
// WALK IN PROGRESS STATE
// =============================================================================
// Estado de la pantalla "Paseo en curso": tiempo, distancia, estado del GPS
// y controles (pausado, finalizando).
// =============================================================================

import '../../domain/entities/walk.dart';

enum WalkInProgressStatus {
  idle,
  tracking,
  paused,
  finishing,
}

enum GpsStatus {
  inactive,
  capturing,
  error,
}

class WalkInProgressState {
  final WalkInProgressStatus status;
  final Walk? walk;
  final String? paseadorId;
  final int elapsedSeconds;
  final double distanceKm;
  final GpsStatus gpsStatus;
  final double? currentPaceMinPerKm;
  final double? averageSpeedKmh;
  final String? errorMessage;
  /// Número de puntos GPS aceptados (para diagnóstico y UI).
  final int gpsPointsCount;
  /// Última lectura GPS (fuente, precisión, resultado del filtro). Solo se muestra en debug.
  final String? gpsDebugInfo;
  /// Aviso informativo para el usuario (p. ej. paseo retomado tras cerrarse la app).
  final String? infoMessage;

  const WalkInProgressState({
    this.status = WalkInProgressStatus.idle,
    this.walk,
    this.paseadorId,
    this.elapsedSeconds = 0,
    this.distanceKm = 0.0,
    this.gpsStatus = GpsStatus.inactive,
    this.currentPaceMinPerKm,
    this.averageSpeedKmh,
    this.errorMessage,
    this.gpsPointsCount = 0,
    this.gpsDebugInfo,
    this.infoMessage,
  });

  bool get isTracking => status == WalkInProgressStatus.tracking;
  bool get isPaused => status == WalkInProgressStatus.paused;
  bool get isFinishing => status == WalkInProgressStatus.finishing;
  bool get hasWalk => walk != null && paseadorId != null;

  WalkInProgressState copyWith({
    WalkInProgressStatus? status,
    Walk? walk,
    String? paseadorId,
    int? elapsedSeconds,
    double? distanceKm,
    GpsStatus? gpsStatus,
    double? currentPaceMinPerKm,
    double? averageSpeedKmh,
    String? errorMessage,
    int? gpsPointsCount,
    String? gpsDebugInfo,
    String? infoMessage,
    bool clearError = false,
  }) {
    return WalkInProgressState(
      status: status ?? this.status,
      walk: walk ?? this.walk,
      paseadorId: paseadorId ?? this.paseadorId,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      distanceKm: distanceKm ?? this.distanceKm,
      gpsStatus: gpsStatus ?? this.gpsStatus,
      currentPaceMinPerKm: currentPaceMinPerKm ?? this.currentPaceMinPerKm,
      averageSpeedKmh: averageSpeedKmh ?? this.averageSpeedKmh,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      gpsPointsCount: gpsPointsCount ?? this.gpsPointsCount,
      gpsDebugInfo: gpsDebugInfo ?? this.gpsDebugInfo,
      infoMessage: infoMessage ?? this.infoMessage,
    );
  }
}
