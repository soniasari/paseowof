import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/firestore_paths.dart';
import '../../domain/entities/pet.dart';
import '../../domain/entities/owner.dart';
import '../mappers/pet_mapper.dart';
import '../mappers/owner_mapper.dart';

abstract class OwnerPetRemoteDataSource {
  Future<void> savePetToFirestore(Pet pet);
  Future<List<Pet>> getPetsByPaseadorId(String paseadorId);
  Future<Pet?> getPetById(String paseadorId, String petId);
  Future<void> deletePet(String paseadorId, String petId);
  Future<void> saveOwnerToFirestore(Owner owner);
  Future<List<Owner>> getOwnersByPaseadorId(String paseadorId);
  Future<Owner?> getOwnerById(String paseadorId, String ownerId);
  Future<void> deleteOwner(String paseadorId, String ownerId);
}

class OwnerPetRemoteDataSourceImpl implements OwnerPetRemoteDataSource {
  final FirebaseFirestore _firestore;

  OwnerPetRemoteDataSourceImpl({
    required FirebaseFirestore firestore,
  }) : _firestore = firestore;

  @override
  Future<void> savePetToFirestore(Pet pet) async {
    try {
      final petMap = PetMapper.toMap(pet);
      // Usar set() sin merge para reemplazar completamente el documento
      // Esto asegura que todos los campos se actualicen correctamente
      await _firestore
          .collection(FirestorePaths.caninosPath(pet.paseadorId))
          .doc(pet.id)
          .set(petMap, SetOptions(merge: false));
    } catch (e) {
      // En modo offline, Firestore puede lanzar errores de red
      // pero los datos se guardan localmente. Verificamos si es un error de red.
      if (e.toString().contains('network') || 
          e.toString().contains('UNAVAILABLE') ||
          e.toString().contains('DEADLINE_EXCEEDED')) {
        // En modo offline, la escritura se encola y se sincronizará cuando haya conexión
        // Consideramos esto como éxito porque los datos están guardados localmente
        return;
      }
      rethrow;
    }
  }

  @override
  Future<List<Pet>> getPetsByPaseadorId(String paseadorId) async {
    try {
      final snapshot = await _firestore
          .collection(FirestorePaths.caninosPath(paseadorId))
          .where('activo', isEqualTo: true)
          .get();

      return snapshot.docs
          .map((doc) => PetMapper.fromMap(doc.id, doc.data()))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<Pet?> getPetById(String paseadorId, String petId) async {
    try {
      final doc = await _firestore
          .collection(FirestorePaths.caninosPath(paseadorId))
          .doc(petId)
          .get();

      if (!doc.exists) {
        return null;
      }

      return PetMapper.fromMap(doc.id, doc.data()!);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> saveOwnerToFirestore(Owner owner) async {
    try {
      final ownerMap = OwnerMapper.toMap(owner);
      // Usar SetOptions para permitir escrituras offline
      // merge: false asegura que se reemplace completamente el documento
      await _firestore
          .collection(FirestorePaths.propietariosPath(owner.paseadorId))
          .doc(owner.id)
          .set(ownerMap, SetOptions(merge: false));
    } catch (e) {
      // En modo offline, Firestore puede lanzar errores de red
      // pero los datos se guardan localmente. Verificamos si es un error de red.
      if (e.toString().contains('network') || 
          e.toString().contains('UNAVAILABLE') ||
          e.toString().contains('DEADLINE_EXCEEDED')) {
        // En modo offline, la escritura se encola y se sincronizará cuando haya conexión
        // Consideramos esto como éxito porque los datos están guardados localmente
        return;
      }
      rethrow;
    }
  }

  @override
  Future<void> deletePet(String paseadorId, String petId) async {
    try {
      await _firestore
          .collection(FirestorePaths.caninosPath(paseadorId))
          .doc(petId)
          .update({'activo': false});
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<Owner>> getOwnersByPaseadorId(String paseadorId) async {
    try {
      final snapshot = await _firestore
          .collection(FirestorePaths.propietariosPath(paseadorId))
          .where('activo', isEqualTo: true)
          .get();

      return snapshot.docs
          .map((doc) => OwnerMapper.fromMap(doc.id, doc.data()))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<Owner?> getOwnerById(String paseadorId, String ownerId) async {
    try {
      final doc = await _firestore
          .collection(FirestorePaths.propietariosPath(paseadorId))
          .doc(ownerId)
          .get();

      if (!doc.exists) {
        return null;
      }

      return OwnerMapper.fromMap(doc.id, doc.data()!);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> deleteOwner(String paseadorId, String ownerId) async {
    try {
      await _firestore
          .collection(FirestorePaths.propietariosPath(paseadorId))
          .doc(ownerId)
          .update({'activo': false});
    } catch (e) {
      rethrow;
    }
  }
}
