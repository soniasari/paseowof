import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/firestore_paths.dart';
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
}

class WalksRemoteDataSourceImpl implements WalksRemoteDataSource {
  final FirebaseFirestore _firestore;

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
      final doc = await _firestore
          .collection(FirestorePaths.paseosPath(paseadorId))
          .doc(walkId)
          .get();

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
      final snapshot = await _firestore
          .collection(FirestorePaths.paseosCaninosPath(paseadorId, paseoId))
          .get();

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
}
