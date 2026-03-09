// =============================================================================
// GPS POINT ENTITY
// =============================================================================
// Representa un punto de la ruta del paseo (lat, lng y opcionalmente precisión
// y timestamp). Se usa en memoria durante el paseo y al persistir los 15
// puntos finales en Firestore.
// =============================================================================

class GpsPoint {
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final double? accuracy;

  const GpsPoint({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.accuracy,
  });

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp.toIso8601String(),
      if (accuracy != null) 'accuracy': accuracy,
    };
  }

  factory GpsPoint.fromMap(Map<String, dynamic> map) {
    return GpsPoint(
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      timestamp: map['timestamp'] != null
          ? DateTime.parse(map['timestamp'] as String)
          : DateTime.now(),
      accuracy: map['accuracy'] != null ? (map['accuracy'] as num).toDouble() : null,
    );
  }
}
