// =============================================================================
// COMPLETE WALK WITH TRACK USE CASE
// =============================================================================
// Al finalizar el paseo: persiste los 15 puntos GPS, la distancia, la duración
// real en minutos y metadatos en gps_points_walk, y actualiza el paseo a estado
// completado con hora de fin, en una sola escritura. Funciona sin conexión: la
// escritura queda en cola y el resultado indica si el servidor ya la confirmó.
// =============================================================================

import 'package:intl/intl.dart';
import '../entities/complete_walk_result.dart';
import '../entities/gps_point.dart';
import '../repositories/walks_repository.dart';

class CompleteWalkWithTrackUseCase {
  CompleteWalkWithTrackUseCase(this._repository);

  final WalksRepository _repository;

  Future<CompleteWalkResult> execute({
    required String paseadorId,
    required String walkId,
    required List<GpsPoint> points,
    required double distanciaKm,
    required int duracionRealMinutos,
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

    final now = DateTime.now();
    final completed = walk.copyWith(
      estado: 'completado',
      horaFin: DateFormat('HH:mm').format(now),
      fechaModificacion: now,
    );

    return _repository.completeWalkWithTrack(
      completed,
      points,
      idsMascotas: idsMascotas,
      nombreMascota: nombreMascota,
      distanciaKm: distanciaKm,
      duracionRealMinutos: duracionRealMinutos,
    );
  }
}
