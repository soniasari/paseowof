import '../../domain/entities/gps_point.dart';
import '../../domain/entities/walk_progress.dart';

class WalkProgressMapper {
  // Puntos en formato compacto [lat, lng, epochMs, accuracy] para ocupar poco.
  static Map<String, dynamic> toJson(WalkProgress progress) {
    return {
      'walkId': progress.walkId,
      'paseadorId': progress.paseadorId,
      'startTime': progress.startTime.millisecondsSinceEpoch,
      'totalPausedSeconds': progress.totalPausedSeconds,
      'pausedAt': progress.pausedAt?.millisecondsSinceEpoch,
      'distanceKm': progress.distanceKm,
      'savedAt': progress.savedAt.millisecondsSinceEpoch,
      'points': progress.points
          .map((p) => [p.latitude, p.longitude, p.timestamp.millisecondsSinceEpoch, p.accuracy])
          .toList(),
    };
  }

  static WalkProgress fromJson(Map<String, dynamic> json) {
    final rawPoints = (json['points'] as List<dynamic>? ?? const []);
    return WalkProgress(
      walkId: json['walkId'] as String,
      paseadorId: json['paseadorId'] as String,
      startTime: DateTime.fromMillisecondsSinceEpoch(json['startTime'] as int),
      totalPausedSeconds: (json['totalPausedSeconds'] as num).toDouble(),
      pausedAt: json['pausedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['pausedAt'] as int)
          : null,
      distanceKm: (json['distanceKm'] as num).toDouble(),
      savedAt: DateTime.fromMillisecondsSinceEpoch(json['savedAt'] as int),
      points: rawPoints.map((e) {
        final p = e as List<dynamic>;
        return GpsPoint(
          latitude: (p[0] as num).toDouble(),
          longitude: (p[1] as num).toDouble(),
          timestamp: DateTime.fromMillisecondsSinceEpoch(p[2] as int),
          accuracy: p.length > 3 && p[3] != null ? (p[3] as num).toDouble() : null,
        );
      }).toList(),
    );
  }
}
