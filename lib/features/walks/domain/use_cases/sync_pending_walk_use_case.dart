// =============================================================================
// SYNC PENDING WALK USE CASE
// =============================================================================
// Si un paseo se finalizó sin conexión y la app se cerró antes de subirlo, su
// respaldo local sigue en la lista de pendientes. Al abrir la app se espera a
// que la base de datos suba las escrituras en cola y recién entonces se borra.
// =============================================================================

import '../repositories/walk_progress_repository.dart';
import '../repositories/walks_repository.dart';

class SyncPendingWalkUseCase {
  SyncPendingWalkUseCase(this._walksRepository, this._progressRepository);

  final WalksRepository _walksRepository;
  final WalkProgressRepository _progressRepository;

  /// Devuelve cuántos paseos pendientes quedaron confirmados en el servidor.
  Future<int> execute() async {
    final pending = await _progressRepository.getPendingSync();
    if (pending.isEmpty) return 0;
    await _walksRepository.waitForPendingWrites();
    for (final walk in pending) {
      await _progressRepository.removePendingSync(walk.walkId);
    }
    return pending.length;
  }
}
