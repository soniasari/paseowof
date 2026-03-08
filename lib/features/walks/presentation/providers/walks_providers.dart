// =============================================================================
// WALKS PROVIDERS — Riverpod
// =============================================================================
// Centraliza todos los providers del feature de paseos: listas por fecha,
// detalle por paseo, caninos del paseo, formularios y use cases de dominio.
// La UI solo consume estos providers; la lógica de negocio está en controllers
// y use cases inyectados por DI.
// =============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/dependency_injection.dart';
import '../../domain/entities/walk.dart';
import '../../domain/entities/walk_pet.dart';
import '../controllers/walk_form_controller.dart';
import '../controllers/walks_controller.dart';

// Re-exportamos desde DI para que el feature de walks dependa solo de este archivo.
export '../../../../core/di/dependency_injection.dart' show
    firebaseFirestoreProvider,
    walksRepositoryProvider,
    updateWalkStatusUseCaseProvider;

// -----------------------------------------------------------------------------
// Listas de paseos (FutureProvider + family para parámetros)
// -----------------------------------------------------------------------------

/// Paseos del paseador para una fecha dada. Solo estado "programado".
/// Usado en Home y calendario para mostrar el día.
final walksByDateProvider = FutureProvider.autoDispose.family<List<Walk>, WalksByDateParams>((ref, params) async {
  final repository = ref.watch(walksRepositoryProvider);
  return await repository.getWalksByPaseadorIdAndDate(params.paseadorId, params.date);
});

/// Paseos del paseador para una fecha, todos los estados (programado, completado, cancelado).
/// Útil para listados y reportes.
final walksByDateAllStatusProvider = FutureProvider.autoDispose.family<List<Walk>, WalksByDateParams>((ref, params) async {
  final repository = ref.watch(walksRepositoryProvider);
  return await repository.getWalksByPaseadorIdAndDateAllStatus(params.paseadorId, params.date);
});

/// Paseos en un rango de fechas. Usado en historial y reportes por período.
final walksByDateRangeProvider = FutureProvider.autoDispose.family<List<Walk>, WalksByDateRangeParams>((ref, params) async {
  final repository = ref.watch(walksRepositoryProvider);
  return await repository.getWalksByPaseadorIdAndDateRange(params.paseadorId, params.fechaInicio, params.fechaFin);
});

// -----------------------------------------------------------------------------
// Parámetros para providers con family (igualdad y hashCode para cache)
// -----------------------------------------------------------------------------

/// Parámetros del provider de paseos por rango de fechas.
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

/// Caninos asociados a un paseo (subcolección paseos_caninos). Usado en detalle y reprogramar.
final walkPetsProvider = FutureProvider.autoDispose.family<List<WalkPet>, WalkPetsParams>((ref, params) async {
  final repository = ref.watch(walksRepositoryProvider);
  return await repository.getWalkPetsByPaseoId(params.paseadorId, params.walkId);
});

/// Parámetros del provider de paseos por fecha (día concreto).
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

/// Parámetros del provider de caninos de un paseo.
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

// -----------------------------------------------------------------------------
// Formularios y estado de UI (StateNotifierProvider / StateProvider)
// -----------------------------------------------------------------------------

/// Controlador del formulario de programar paseo (fecha, horario, canino, etc.).
final walkFormControllerProvider = StateNotifierProvider.autoDispose<WalkFormController, WalkFormState>((ref) {
  return WalkFormController();
});

/// Estado local del formulario de programar: fecha, propietario, caninos, horario.
final selectedFechaProvider = StateProvider.autoDispose<DateTime?>((ref) => null);
final selectedPropietarioIdProvider = StateProvider.autoDispose<String?>((ref) => null);
final selectedCaninosIdsProvider = StateProvider.autoDispose<List<String>>((ref) => []);
final selectedCaninoIdProvider = StateProvider.autoDispose<String?>((ref) => null);
final selectedHorarioProvider = StateProvider.autoDispose<String?>((ref) => null);

/// Controller de paseos: programar, reprogramar y actualizar estado (completado/cancelado).
/// Depende del repositorio y de [updateWalkStatusUseCaseProvider] inyectado por DI.
final walksControllerProvider = StateNotifierProvider.autoDispose<WalksController, AsyncValue<void>>((ref) {
  final repository = ref.watch(walksRepositoryProvider);
  final updateWalkStatusUseCase = ref.watch(updateWalkStatusUseCaseProvider);
  return WalksController(repository, updateWalkStatusUseCase);
});