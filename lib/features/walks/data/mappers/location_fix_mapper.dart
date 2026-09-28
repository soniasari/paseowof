import 'package:geolocator/geolocator.dart';
import '../../domain/entities/location_fix.dart';

class LocationFixMapper {
  // Pasamos la posición del plugin a la entidad del dominio
  static LocationFix fromPosition(Position position) {
    return LocationFix(
      latitude: position.latitude,
      longitude: position.longitude,
      timestamp: position.timestamp,
      accuracy: position.accuracy,
    );
  }
}
