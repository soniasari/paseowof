import '../entities/gps_point.dart';
import '../entities/walk.dart';
import '../entities/walk_pet.dart';

abstract class WalksRepository {
  Future<void> saveWalk(Walk walk);
  Future<List<Walk>> getWalksByPaseadorIdAndDate(String paseadorId, DateTime date);
  Future<List<Walk>> getWalksByPaseadorIdAndDateAllStatus(String paseadorId, DateTime date);
  Future<List<Walk>> getWalksByPaseadorId(String paseadorId);
  Future<List<Walk>> getWalksByPaseadorIdAndDateRange(String paseadorId, DateTime fechaInicio, DateTime fechaFin);
  Future<Walk?> getWalkById(String paseadorId, String walkId);
  Future<void> saveWalkPet(String paseadorId, String paseoId, WalkPet walkPet);
  Future<List<WalkPet>> getWalkPetsByPaseoId(String paseadorId, String paseoId);
  Future<void> deleteWalk(String paseadorId, String walkId);
  /// Guarda los 15 puntos, distancia total y metadatos en la subcolección gps_points_walk del paseo.
  Future<void> saveWalkTrack(
    String paseadorId,
    String walkId,
    List<GpsPoint> points, {
    required String idPropietario,
    required List<String> idsMascotas,
    required String nombreMascota,
    required double distanciaKm,
  });
}
