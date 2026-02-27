import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/dependency_injection.dart';
import '../../domain/entities/pet.dart';
import '../../domain/entities/owner.dart';

// Re-exportar providers de DI para mantener compatibilidad
export '../../../../core/di/dependency_injection.dart' show firebaseFirestoreProvider, ownerPetRepositoryProvider;

// Provider para obtener la lista de propietarios del paseador actual
final ownersListProvider = FutureProvider.autoDispose.family<List<Owner>, String>((ref, paseadorId) async {
  final repository = ref.watch(ownerPetRepositoryProvider);
  return await repository.getOwnersByPaseadorId(paseadorId);
});

// Provider para obtener la lista de caninos del paseador actual
final petsListProvider = FutureProvider.autoDispose.family<List<Pet>, String>((ref, paseadorId) async {
  final repository = ref.watch(ownerPetRepositoryProvider);
  return await repository.getPetsByPaseadorId(paseadorId);
});

// Providers para el estado del formulario
final selectedOwnerIdProvider = StateProvider.autoDispose<String?>((ref) => null);
final selectedTamanoProvider = StateProvider.autoDispose<String?>((ref) => null);
final selectedNivelEnergiaProvider = StateProvider.autoDispose<String?>((ref) => null);
