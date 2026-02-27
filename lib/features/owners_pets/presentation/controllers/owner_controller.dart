import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/owner.dart';
import '../../domain/repositories/owner_pet_repository.dart';
import '../providers/owner_pet_providers.dart';

class OwnerController extends StateNotifier<AsyncValue<void>> {
  OwnerController(this._repository) : super(const AsyncValue.data(null));

  final OwnerPetRepository _repository;

  Future<void> registerOwner({
    required String paseadorId,
    required String nombre,
    required String ci,
    String? telefono,
    String? direccion,
    String? email,
  }) async {
    try {
      state = const AsyncValue.loading();

      // Crear objeto Owner
      final owner = Owner(
        id: '', // Se generará automáticamente por Firestore
        paseadorId: paseadorId,
        nombre: nombre,
        ci: ci,
        telefono: telefono,
        direccion: direccion,
        email: email,
        fechaRegistro: DateTime.now(),
        activo: true,
      );

      // Generar ID único para el propietario
      final ownerId = FirebaseFirestore.instance
          .collection('paseadores')
          .doc(paseadorId)
          .collection('propietarios')
          .doc()
          .id;

      final ownerWithId = Owner(
        id: ownerId,
        paseadorId: owner.paseadorId,
        nombre: owner.nombre,
        ci: owner.ci,
        telefono: owner.telefono,
        direccion: owner.direccion,
        email: owner.email,
        fechaRegistro: owner.fechaRegistro,
        activo: owner.activo,
      );

      await _repository.saveOwner(ownerWithId);
      state = const AsyncValue.data(null);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      rethrow;
    }
  }

  Future<void> updateOwner({
    required String paseadorId,
    required String ownerId,
    required String nombre,
    required String ci,
    String? telefono,
    String? direccion,
    String? email,
  }) async {
    try {
      state = const AsyncValue.loading();

      // Obtener el propietario existente para preservar fechaRegistro
      final existingOwner = await _repository.getOwnerById(paseadorId, ownerId);
      if (existingOwner == null) {
        throw Exception('Propietario no encontrado');
      }

      // Crear objeto Owner actualizado
      final updatedOwner = Owner(
        id: ownerId,
        paseadorId: paseadorId,
        nombre: nombre,
        ci: ci,
        telefono: telefono,
        direccion: direccion,
        email: email,
        fechaRegistro: existingOwner.fechaRegistro, // Preservar fecha original
        activo: existingOwner.activo, // Preservar estado activo
      );

      await _repository.saveOwner(updatedOwner);
      state = const AsyncValue.data(null);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      rethrow;
    }
  }
}

final ownerControllerProvider = StateNotifierProvider.autoDispose<OwnerController, AsyncValue<void>>((ref) {
  final repository = ref.watch(ownerPetRepositoryProvider);
  return OwnerController(repository);
});

