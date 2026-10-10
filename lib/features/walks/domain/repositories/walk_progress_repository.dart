import '../entities/walk_progress.dart';

/// Respaldo en el teléfono de los paseos, en dos espacios separados:
/// - el paseo en curso (uno a la vez; cada guardado reemplaza al anterior);
/// - los paseos finalizados sin conexión que aún no llegaron al servidor.
abstract class WalkProgressRepository {
  Future<void> save(WalkProgress progress);

  /// Progreso de este paseo, o null si no hay, es de otro paseo o es demasiado antiguo.
  Future<WalkProgress?> getFor({required String walkId, required String paseadorId});

  Future<void> clear();

  /// Guarda una copia del paseo finalizado hasta que el servidor confirme la subida.
  Future<void> addPendingSync(WalkProgress progress);

  Future<List<WalkProgress>> getPendingSync();

  Future<void> removePendingSync(String walkId);
}
