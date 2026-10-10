// =============================================================================
// LOCATION FIX ENTITY
// =============================================================================
// Lectura cruda del GPS del dispositivo, independiente del plugin que la
// entrega. El filtro del paseo la convierte en GpsPoint suavizado.
// =============================================================================

class LocationFix {
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  /// Radio de precisión en metros informado por el dispositivo.
  final double accuracy;

  const LocationFix({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    required this.accuracy,
  });

  bool get isValid =>
      !latitude.isNaN && !longitude.isNaN && !latitude.isInfinite && !longitude.isInfinite;
}
