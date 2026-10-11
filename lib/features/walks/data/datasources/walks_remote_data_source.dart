import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/firestore_paths.dart';
import '../../domain/entities/complete_walk_result.dart';
import '../../domain/entities/gps_point.dart';
import '../../domain/entities/walk.dart';
import '../../domain/entities/walk_pet.dart';
import '../mappers/walk_mapper.dart';
import '../mappers/walk_pet_mapper.dart';

abstract class WalksRemoteDataSource {
  Future<void> saveWalkToFirestore(Walk walk);
  Future<List<Walk>> getWalksByPaseadorIdAndDate(String paseadorId, DateTime date);
  Future<List<Walk>> getWalksByPaseadorIdAndDateAllStatus(String paseadorId, DateTime date);
  Future<List<Walk>> getWalksByPaseadorId(String paseadorId);
  Future<List<Walk>> getWalksByPaseadorIdAndDateRange(String paseadorId, DateTime fechaInicio, DateTime fechaFin);
  Future<Walk?> getWalkById(String paseadorId, String walkId);
  Future<void> saveWalkPetToFirestore(String paseadorId, String paseoId, WalkPet walkPet);
  Future<List<WalkPet>> getWalkPetsByPaseoId(String paseadorId, String paseoId);
  Future<void> deleteWalk(String paseadorId, String walkId);
  /// Guarda en un solo lote los 15 puntos GPS (subcolección gps_points_walk) y el paseo completado.
  Future<CompleteWalkResult> completeWalkWithTrack(
    Walk completedWalk,
    List<GpsPoint> points, {
    required List<String> idsMascotas,
    required String nombreMascota,
    required double distanciaKm,
    required int duracionRealMinutos,
  });
  /// Se completa cuando el servidor confirmó todas las escrituras en cola.
  Future<void> waitForPendingWrites();
}

class WalksRemoteDataSourceImpl implements WalksRemoteDataSource {
  final FirebaseFirestore _firestore;

  /// Si el servidor no confirma en este tiempo, se considera sin conexión.
  static const Duration _serverAckTimeout = Duration(seconds: 5);
  static const Duration _serverReadTimeout = Duration(seconds: 4);

  WalksRemoteDataSourceImpl({
    required FirebaseFirestore firestore,
  }) : _firestore = firestore;

  @override
  Future<void> saveWalkToFirestore(Walk walk) async {
    try {
      final walkMap = WalkMapper.toMap(walk);
      await _firestore
          .collection(FirestorePaths.paseosPath(walk.paseadorId))
          .doc(walk.id)
          .set(walkMap, SetOptions(merge: false));
    } catch (e) {
      // Sin conexión Firestore tira pero guarda local; cuando haya internet sube
      if (e.toString().contains('network') || 
          e.toString().contains('UNAVAILABLE') ||
          e.toString().contains('DEADLINE_EXCEEDED')) {
        // Lo damos por bien guardado (queda en cola local)
        return;
      }
      rethrow;
    }
  }

  @override
  Future<List<Walk>> getWalksByPaseadorIdAndDate(String paseadorId, DateTime date) async {
    try {
      // Traemos paseos (servidor + caché para que funcione offline); si falla usamos solo caché
      QuerySnapshot<Map<String, dynamic>> snapshot;
      try {
        snapshot = await _firestore
            .collection(FirestorePaths.paseosPath(paseadorId))
            .where('estado', isEqualTo: 'programado')
            .get(const GetOptions(source: Source.serverAndCache));
      } catch (e) {
        // Sin conexión usamos solo lo que hay en caché
        snapshot = await _firestore
            .collection(FirestorePaths.paseosPath(paseadorId))
            .where('estado', isEqualTo: 'programado')
            .get(const GetOptions(source: Source.cache));
      }

      // Comparar solo día/mes/año (evita problemas de zona horaria)
      final targetYear = date.year;
      final targetMonth = date.month;
      final targetDay = date.day;

      return snapshot.docs
          .map((doc) => WalkMapper.fromMap(doc.id, doc.data()))
          .where((walk) =>
              walk.fechaPaseo.year == targetYear &&
              walk.fechaPaseo.month == targetMonth &&
              walk.fechaPaseo.day == targetDay)
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<List<Walk>> getWalksByPaseadorIdAndDateAllStatus(String paseadorId, DateTime date) async {
    try {
      // Igual pero traemos todos los estados (programado, completado, cancelado)
      QuerySnapshot<Map<String, dynamic>> snapshot;
      try {
        snapshot = await _firestore
            .collection(FirestorePaths.paseosPath(paseadorId))
            .get(const GetOptions(source: Source.serverAndCache));
      } catch (e) {
        // Sin conexión usamos solo lo que hay en caché
        snapshot = await _firestore
            .collection(FirestorePaths.paseosPath(paseadorId))
            .get(const GetOptions(source: Source.cache));
      }

      final targetYear = date.year;
      final targetMonth = date.month;
      final targetDay = date.day;

      return snapshot.docs
          .map((doc) => WalkMapper.fromMap(doc.id, doc.data()))
          .where((walk) =>
              walk.fechaPaseo.year == targetYear &&
              walk.fechaPaseo.month == targetMonth &&
              walk.fechaPaseo.day == targetDay)
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<Walk>> getWalksByPaseadorId(String paseadorId) async {
    try {
      final snapshot = await _firestore
          .collection(FirestorePaths.paseosPath(paseadorId))
          .where('estado', isEqualTo: 'programado')
          .get();

      return snapshot.docs
          .map((doc) => WalkMapper.fromMap(doc.id, doc.data()))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<Walk>> getWalksByPaseadorIdAndDateRange(String paseadorId, DateTime fechaInicio, DateTime fechaFin) async {
    try {
      // Paseos en un rango de fechas
      final snapshot = await _firestore
          .collection(FirestorePaths.paseosPath(paseadorId))
          .get();

      // Solo día/mes/año para comparar
      final inicioNormalizado = DateTime(fechaInicio.year, fechaInicio.month, fechaInicio.day);
      final finNormalizado = DateTime(fechaFin.year, fechaFin.month, fechaFin.day).add(const Duration(days: 1)).subtract(const Duration(seconds: 1));

      return snapshot.docs
          .map((doc) => WalkMapper.fromMap(doc.id, doc.data()))
          .where((walk) {
            final walkDate = DateTime(
              walk.fechaPaseo.year,
              walk.fechaPaseo.month,
              walk.fechaPaseo.day,
            );
            return walkDate.isAfter(inicioNormalizado.subtract(const Duration(seconds: 1))) &&
                   walkDate.isBefore(finNormalizado);
          })
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<Walk?> getWalkById(String paseadorId, String walkId) async {
    try {
      final ref = _firestore.collection(FirestorePaths.paseosPath(paseadorId)).doc(walkId);
      DocumentSnapshot<Map<String, dynamic>> doc;
      try {
        doc = await ref
            .get(const GetOptions(source: Source.serverAndCache))
            .timeout(_serverReadTimeout);
      } catch (e) {
        // Sin conexión usamos solo lo que hay en caché
        doc = await ref.get(const GetOptions(source: Source.cache));
      }

      if (!doc.exists) {
        return null;
      }

      return WalkMapper.fromMap(doc.id, doc.data()!);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> saveWalkPetToFirestore(String paseadorId, String paseoId, WalkPet walkPet) async {
    try {
      final walkPetMap = WalkPetMapper.toMap(walkPet);
      await _firestore
          .collection(FirestorePaths.paseosCaninosPath(paseadorId, paseoId))
          .doc(walkPet.id)
          .set(walkPetMap, SetOptions(merge: false));
    } catch (e) {
      // Sin conexión Firestore tira pero guarda local; cuando haya internet sube
      if (e.toString().contains('network') || 
          e.toString().contains('UNAVAILABLE') ||
          e.toString().contains('DEADLINE_EXCEEDED')) {
        // Lo damos por bien guardado (queda en cola local)
        return;
      }
      rethrow;
    }
  }

  @override
  Future<List<WalkPet>> getWalkPetsByPaseoId(String paseadorId, String paseoId) async {
    try {
      final query = _firestore.collection(FirestorePaths.paseosCaninosPath(paseadorId, paseoId));
      QuerySnapshot<Map<String, dynamic>> snapshot;
      try {
        snapshot = await query
            .get(const GetOptions(source: Source.serverAndCache))
            .timeout(_serverReadTimeout);
      } catch (e) {
        // Sin conexión usamos solo lo que hay en caché
        snapshot = await query.get(const GetOptions(source: Source.cache));
      }

      return snapshot.docs
          .map((doc) => WalkPetMapper.fromMap(doc.id, doc.data()))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> deleteWalk(String paseadorId, String walkId) async {
    try {
      await _firestore
          .collection(FirestorePaths.paseosPath(paseadorId))
          .doc(walkId)
          .update({'estado': 'cancelado'});
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<CompleteWalkResult> completeWalkWithTrack(
    Walk completedWalk,
    List<GpsPoint> points, {
    required List<String> idsMascotas,
    required String nombreMascota,
    required double distanciaKm,
    required int duracionRealMinutos,
  }) async {
    final paseadorId = completedWalk.paseadorId;
    final walkId = completedWalk.id;
    // Ruta y estado en un solo lote: el servidor aplica las dos escrituras o ninguna.
    final batch = _firestore.batch()
      ..set(_firestore.doc(FirestorePaths.gpsPointsWalkDoc(paseadorId, walkId)), {
        'points': points.map((p) => p.toMap()).toList(),
        'idPaseo': walkId,
        'idPropietario': completedWalk.propietarioId,
        'idMascota': idsMascotas.isNotEmpty ? idsMascotas.first : '',
        'idsMascotas': idsMascotas,
        'nombreMascota': nombreMascota,
        'distanciaKm': distanciaKm,
        'duracionRealMinutos': duracionRealMinutos,
      })
      ..set(
        _firestore.collection(FirestorePaths.paseosPath(paseadorId)).doc(walkId),
        WalkMapper.toMap(completedWalk),
        SetOptions(merge: false),
      );

    // Sin conexión, commit() no falla: deja el lote en la cola persistente de
    // Firestore y solo se completa cuando el servidor lo confirma.
    final commit = batch.commit();
    try {
      await commit.timeout(_serverAckTimeout);
      return CompleteWalkResult(synced: true, whenSynced: Future<void>.value());
    } on TimeoutException {
      return CompleteWalkResult(synced: false, whenSynced: commit);
    }
  }

  @override
  Future<void> waitForPendingWrites() => _firestore.waitForPendingWrites();
}
