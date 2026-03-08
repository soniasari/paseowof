import '../repositories/walks_repository.dart';

// Actualiza estado del paseo (completado, cancelado). La UI no usa el repo directo.
class UpdateWalkStatusUseCase {
  UpdateWalkStatusUseCase(this._repository);

  final WalksRepository _repository;

  // Tira si el paseo no existe
  Future<void> execute({
    required String paseadorId,
    required String walkId,
    required String estado,
    String? motivoCancelacion,
  }) async {
    final walk = await _repository.getWalkById(paseadorId, walkId);
    if (walk == null) {
      throw Exception('Paseo no encontrado');
    }
    final updatedWalk = walk.copyWith(
      estado: estado,
      fechaModificacion: DateTime.now(),
      motivoCancelacion: motivoCancelacion,
    );
    await _repository.saveWalk(updatedWalk);
  }
}
