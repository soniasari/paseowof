import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/pet.dart';
import '../../domain/repositories/owner_pet_repository.dart';
import '../providers/owner_pet_providers.dart';

class PetController extends StateNotifier<AsyncValue<void>> {
  PetController(this._repository) : super(const AsyncValue.data(null));

  final OwnerPetRepository _repository;

  Future<void> registerPet({
    required String paseadorId,
    required String propietarioId,
    required String nombre,
    String? raza,
    int? edad,
    String? tamano,
    String? nivelEnergia,
    String? observaciones,
    double? peso,
    String? color,
    String? foto,
  }) async {
    try {
      state = const AsyncValue.loading();

      // Crear objeto Pet
      final pet = Pet(
        id: '', // Se generará automáticamente por Firestore
        paseadorId: paseadorId,
        propietarioId: propietarioId,
        nombre: nombre,
        raza: raza,
        edad: edad,
        tamano: tamano,
        nivelEnergia: nivelEnergia,
        observaciones: observaciones,
        peso: peso,
        color: color,
        foto: foto,
        fechaRegistro: DateTime.now(),
        activo: true,
      );

      // Generar ID único para el canino
      final petId = FirebaseFirestore.instance
          .collection('paseadores')
          .doc(paseadorId)
          .collection('caninos')
          .doc()
          .id;

      final petWithId = Pet(
        id: petId,
        paseadorId: pet.paseadorId,
        propietarioId: pet.propietarioId,
        nombre: pet.nombre,
        raza: pet.raza,
        edad: pet.edad,
        tamano: pet.tamano,
        nivelEnergia: pet.nivelEnergia,
        observaciones: pet.observaciones,
        peso: pet.peso,
        color: pet.color,
        foto: pet.foto,
        fechaRegistro: pet.fechaRegistro,
        activo: pet.activo,
      );

      await _repository.savePet(petWithId);
      state = const AsyncValue.data(null);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      rethrow;
    }
  }

  Future<void> updatePet({
    required String paseadorId,
    required String petId,
    required String propietarioId,
    required String nombre,
    String? raza,
    int? edad,
    String? tamano,
    String? nivelEnergia,
    String? observaciones,
    double? peso,
    String? color,
    String? foto,
  }) async {
    try {
      state = const AsyncValue.loading();

      // Obtener el canino existente para preservar fechaRegistro
      final existingPet = await _repository.getPetById(paseadorId, petId);
      if (existingPet == null) {
        throw Exception('Canino no encontrado');
      }

      // Crear objeto Pet actualizado
      final updatedPet = Pet(
        id: petId,
        paseadorId: paseadorId,
        propietarioId: propietarioId,
        nombre: nombre,
        raza: raza,
        edad: edad,
        tamano: tamano,
        nivelEnergia: nivelEnergia,
        observaciones: observaciones,
        peso: peso,
        color: color,
        foto: foto,
        fechaRegistro: existingPet.fechaRegistro, // Preservar fecha original
        activo: existingPet.activo, // Preservar estado activo
      );

      await _repository.savePet(updatedPet);
      state = const AsyncValue.data(null);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      rethrow;
    }
  }
}

final petControllerProvider = StateNotifierProvider.autoDispose<PetController, AsyncValue<void>>((ref) {
  final repository = ref.watch(ownerPetRepositoryProvider);
  return PetController(repository);
});

