import '../../domain/entities/pet.dart';
import '../../domain/entities/owner.dart';
import '../../domain/repositories/owner_pet_repository.dart';
import '../datasources/owner_pet_remote_data_source.dart';

class OwnerPetRepositoryImpl implements OwnerPetRepository {
  final OwnerPetRemoteDataSource _remoteDataSource;

  OwnerPetRepositoryImpl(this._remoteDataSource);

  @override
  Future<void> savePet(Pet pet) async {
    await _remoteDataSource.savePetToFirestore(pet);
  }

  @override
  Future<List<Pet>> getPetsByPaseadorId(String paseadorId) async {
    return await _remoteDataSource.getPetsByPaseadorId(paseadorId);
  }

  @override
  Future<Pet?> getPetById(String paseadorId, String petId) async {
    return await _remoteDataSource.getPetById(paseadorId, petId);
  }

  @override
  Future<void> saveOwner(Owner owner) async {
    await _remoteDataSource.saveOwnerToFirestore(owner);
  }

  @override
  Future<void> deletePet(String paseadorId, String petId) async {
    await _remoteDataSource.deletePet(paseadorId, petId);
  }

  @override
  Future<List<Owner>> getOwnersByPaseadorId(String paseadorId) async {
    return await _remoteDataSource.getOwnersByPaseadorId(paseadorId);
  }

  @override
  Future<Owner?> getOwnerById(String paseadorId, String ownerId) async {
    return await _remoteDataSource.getOwnerById(paseadorId, ownerId);
  }

  @override
  Future<void> deleteOwner(String paseadorId, String ownerId) async {
    await _remoteDataSource.deleteOwner(paseadorId, ownerId);
  }
}
