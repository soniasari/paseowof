import '../../domain/entities/walk.dart';
import '../../domain/entities/walk_pet.dart';
import '../../domain/repositories/walks_repository.dart';
import '../datasources/walks_remote_data_source.dart';

class WalksRepositoryImpl implements WalksRepository {
  final WalksRemoteDataSource _remoteDataSource;

  WalksRepositoryImpl(this._remoteDataSource);

  @override
  Future<void> saveWalk(Walk walk) async {
    await _remoteDataSource.saveWalkToFirestore(walk);
  }

  @override
  Future<List<Walk>> getWalksByPaseadorIdAndDate(String paseadorId, DateTime date) async {
    return await _remoteDataSource.getWalksByPaseadorIdAndDate(paseadorId, date);
  }

  @override
  Future<List<Walk>> getWalksByPaseadorIdAndDateAllStatus(String paseadorId, DateTime date) async {
    return await _remoteDataSource.getWalksByPaseadorIdAndDateAllStatus(paseadorId, date);
  }

  @override
  Future<List<Walk>> getWalksByPaseadorId(String paseadorId) async {
    return await _remoteDataSource.getWalksByPaseadorId(paseadorId);
  }

  @override
  Future<List<Walk>> getWalksByPaseadorIdAndDateRange(String paseadorId, DateTime fechaInicio, DateTime fechaFin) async {
    return await _remoteDataSource.getWalksByPaseadorIdAndDateRange(paseadorId, fechaInicio, fechaFin);
  }

  @override
  Future<Walk?> getWalkById(String paseadorId, String walkId) async {
    return await _remoteDataSource.getWalkById(paseadorId, walkId);
  }

  @override
  Future<void> saveWalkPet(String paseadorId, String paseoId, WalkPet walkPet) async {
    await _remoteDataSource.saveWalkPetToFirestore(paseadorId, paseoId, walkPet);
  }

  @override
  Future<List<WalkPet>> getWalkPetsByPaseoId(String paseadorId, String paseoId) async {
    return await _remoteDataSource.getWalkPetsByPaseoId(paseadorId, paseoId);
  }

  @override
  Future<void> deleteWalk(String paseadorId, String walkId) async {
    await _remoteDataSource.deleteWalk(paseadorId, walkId);
  }
}
