// =============================================================================
// WALK PROGRESS ENTITY
// =============================================================================
// Estado de un paseo en curso que se guarda solo en el teléfono para poder
// retomarlo si el sistema cierra la app. No se sube a Firestore.
// =============================================================================

import 'gps_point.dart';

class WalkProgress {
  final String walkId;
  final String paseadorId;
  final DateTime startTime;
  final double totalPausedSeconds;
  /// Si el paseo estaba en pausa al guardarse, momento en que se pausó.
  final DateTime? pausedAt;
  final double distanceKm;
  final List<GpsPoint> points;
  final DateTime savedAt;

  const WalkProgress({
    required this.walkId,
    required this.paseadorId,
    required this.startTime,
    required this.totalPausedSeconds,
    required this.pausedAt,
    required this.distanceKm,
    required this.points,
    required this.savedAt,
  });
}
