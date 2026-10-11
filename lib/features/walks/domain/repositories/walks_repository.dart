import '../entities/complete_walk_result.dart';
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
  /// Guarda los 15 puntos y el paseo completado en una sola escritura atómica.
  /// Sin conexión no espera al servidor: devuelve [CompleteWalkResult.synced] en false.
  Future<CompleteWalkResult> completeWalkWithTrack(
    Walk completedWalk,
    List<GpsPoint> points, {
    required List<String> idsMascotas,
    required String nombreMascota,
    required double distanciaKm,
    required int duracionRealMinutos,
  });
  /// Se completa cuando el servidor confirmó todas las escrituras pendientes.
  Future<void> waitForPendingWrites();
}
