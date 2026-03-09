// =============================================================================
// COMPLETE WALK WITH TRACK USE CASE
// =============================================================================
// Al finalizar el paseo: persiste los 15 puntos GPS y metadatos en
// gps_points_walk y actualiza el paseo a estado completado con hora de fin.
// =============================================================================

import 'package:intl/intl.dart';
import '../entities/gps_point.dart';
import '../repositories/walks_repository.dart';

class CompleteWalkWithTrackUseCase {
  CompleteWalkWithTrackUseCase(this._repository);

  final WalksRepository _repository;

  /// Guarda los 15 puntos, distancia total y metadatos en Firestore y marca el paseo como completado.
  Future<void> execute({
    required String paseadorId,
    required String walkId,
    required List<GpsPoint> points,
    required double distanciaKm,
  }) async {
    if (points.length != 15) {
      throw ArgumentError('Se deben enviar exactamente 15 puntos; recibidos: ${points.length}');
    }

    final walk = await _repository.getWalkById(paseadorId, walkId);
    if (walk == null) {
      throw Exception('Paseo no encontrado');
    }

    final walkPets = await _repository.getWalkPetsByPaseoId(paseadorId, walkId);
    final idsMascotas = walkPets.map((p) => p.caninoId).toList();
    final nombreMascota = walkPets.isEmpty
        ? '—'
        : walkPets.map((p) => p.nombreCanino).join(', ');

    await _repository.saveWalkTrack(
      paseadorId,
      walkId,
      points,
      idPropietario: walk.propietarioId,
      idsMascotas: idsMascotas,
      nombreMascota: nombreMascota,
      distanciaKm: distanciaKm,
    );

    final now = DateTime.now();
    final horaFin = DateFormat('HH:mm').format(now);
    final updated = walk.copyWith(
      estado: 'completado',
      horaFin: horaFin,
      fechaModificacion: now,
    );
    await _repository.saveWalk(updated);
  }
}
