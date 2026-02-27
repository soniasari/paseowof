import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/dependency_injection.dart';
import '../../domain/entities/walk.dart';
import '../../domain/entities/walk_pet.dart';
import '../controllers/walk_form_controller.dart';

// Re-exportar providers de DI para mantener compatibilidad
export '../../../../core/di/dependency_injection.dart' show firebaseFirestoreProvider, walksRepositoryProvider;

// Provider para obtener la lista de paseos del paseador por fecha (solo programados)
final walksByDateProvider = FutureProvider.autoDispose.family<List<Walk>, WalksByDateParams>((ref, params) async {
  final repository = ref.watch(walksRepositoryProvider);
  return await repository.getWalksByPaseadorIdAndDate(params.paseadorId, params.date);
});

// Provider para obtener la lista de paseos del paseador por fecha (todos los estados)
final walksByDateAllStatusProvider = FutureProvider.autoDispose.family<List<Walk>, WalksByDateParams>((ref, params) async {
  final repository = ref.watch(walksRepositoryProvider);
  return await repository.getWalksByPaseadorIdAndDateAllStatus(params.paseadorId, params.date);
});

// Provider para obtener la lista de paseos del paseador por rango de fechas
final walksByDateRangeProvider = FutureProvider.autoDispose.family<List<Walk>, WalksByDateRangeParams>((ref, params) async {
  final repository = ref.watch(walksRepositoryProvider);
  return await repository.getWalksByPaseadorIdAndDateRange(params.paseadorId, params.fechaInicio, params.fechaFin);
});

// Clase helper para pasar parámetros al provider de rango de fechas
class WalksByDateRangeParams {
  final String paseadorId;
  final DateTime fechaInicio;
  final DateTime fechaFin;

  WalksByDateRangeParams({
    required this.paseadorId,
    required this.fechaInicio,
    required this.fechaFin,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WalksByDateRangeParams &&
          runtimeType == other.runtimeType &&
          paseadorId == other.paseadorId &&
          fechaInicio.year == other.fechaInicio.year &&
          fechaInicio.month == other.fechaInicio.month &&
          fechaInicio.day == other.fechaInicio.day &&
          fechaFin.year == other.fechaFin.year &&
          fechaFin.month == other.fechaFin.month &&
          fechaFin.day == other.fechaFin.day;

  @override
  int get hashCode => paseadorId.hashCode ^ 
      fechaInicio.year.hashCode ^ 
      fechaInicio.month.hashCode ^ 
      fechaInicio.day.hashCode ^
      fechaFin.year.hashCode ^ 
      fechaFin.month.hashCode ^ 
      fechaFin.day.hashCode;
}

// Provider para obtener los perros de un paseo
final walkPetsProvider = FutureProvider.autoDispose.family<List<WalkPet>, WalkPetsParams>((ref, params) async {
  final repository = ref.watch(walksRepositoryProvider);
  return await repository.getWalkPetsByPaseoId(params.paseadorId, params.walkId);
});

// Clase helper para pasar parámetros al provider
class WalksByDateParams {
  final String paseadorId;
  final DateTime date;

  WalksByDateParams({
    required this.paseadorId,
    required this.date,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WalksByDateParams &&
          runtimeType == other.runtimeType &&
          paseadorId == other.paseadorId &&
          other.date.year == date.year &&
          other.date.month == date.month &&
          other.date.day == date.day;

  @override
  int get hashCode => paseadorId.hashCode ^ date.year.hashCode ^ date.month.hashCode ^ date.day.hashCode;
}

// Clase helper para pasar parámetros al provider de walk pets
class WalkPetsParams {
  final String paseadorId;
  final String walkId;

  WalkPetsParams({
    required this.paseadorId,
    required this.walkId,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WalkPetsParams &&
          runtimeType == other.runtimeType &&
          paseadorId == other.paseadorId &&
          walkId == other.walkId;

  @override
  int get hashCode => paseadorId.hashCode ^ walkId.hashCode;
}

// Provider para el WalkFormController
final walkFormControllerProvider = StateNotifierProvider.autoDispose<WalkFormController, WalkFormState>((ref) {
  return WalkFormController();
});

// Providers para el estado del formulario de programar paseo
final selectedFechaProvider = StateProvider.autoDispose<DateTime?>((ref) => null);
final selectedPropietarioIdProvider = StateProvider.autoDispose<String?>((ref) => null);
final selectedCaninosIdsProvider = StateProvider.autoDispose<List<String>>((ref) => []);
final selectedCaninoIdProvider = StateProvider.autoDispose<String?>((ref) => null);
final selectedHorarioProvider = StateProvider.autoDispose<String?>((ref) => null);