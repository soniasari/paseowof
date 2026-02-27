import '../entities/pet.dart';
import '../entities/owner.dart';

abstract class OwnerPetRepository {
  Future<void> savePet(Pet pet);
  Future<List<Pet>> getPetsByPaseadorId(String paseadorId);
  Future<Pet?> getPetById(String paseadorId, String petId);
  Future<void> deletePet(String paseadorId, String petId);
  Future<void> saveOwner(Owner owner);
  Future<List<Owner>> getOwnersByPaseadorId(String paseadorId);
  Future<Owner?> getOwnerById(String paseadorId, String ownerId);
  Future<void> deleteOwner(String paseadorId, String ownerId);
}
