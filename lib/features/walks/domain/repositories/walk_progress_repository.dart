import '../entities/walk_progress.dart';

/// Progreso del paseo en curso guardado en el teléfono. Solo hay uno a la vez:
/// cada guardado reemplaza al anterior.
abstract class WalkProgressRepository {
  Future<void> save(WalkProgress progress);

  /// Progreso de este paseo, o null si no hay, es de otro paseo o es demasiado antiguo.
  Future<WalkProgress?> getFor({required String walkId, required String paseadorId});

  Future<void> clear();
}
