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
      // En modo offline, Firestore puede lanzar errores de red
      // pero los datos se guardan localmente. Verificamos si es un error de red.
      if (e.toString().contains('network') || 
          e.toString().contains('UNAVAILABLE') ||
          e.toString().contains('DEADLINE_EXCEEDED')) {
        // En modo offline, la escritura se encola y se sincronizará cuando haya conexión
        // Consideramos esto como éxito porque los datos están guardados localmente
        return;
      }
      rethrow;
    }
  }

  @override
  Future<List<Walk>> getWalksByPaseadorIdAndDate(String paseadorId, DateTime date) async {
    try {
      // Obtener todos los paseos programados y filtrar por fecha en memoria
      // Usar Source.serverAndCache para incluir datos locales pendientes de sincronización
      // Esto es crítico para el bloqueo de horarios en modo offline
      // Si falla, intentar con Source.cache para obtener solo datos locales
      QuerySnapshot<Map<String, dynamic>> snapshot;
      try {
        snapshot = await _firestore
            .collection(FirestorePaths.paseosPath(paseadorId))
            .where('estado', isEqualTo: 'programado')
            .get(const GetOptions(source: Source.serverAndCache));
      } catch (e) {
        // Si falla (sin conexión), usar solo caché local
        snapshot = await _firestore
            .collection(FirestorePaths.paseosPath(paseadorId))
            .where('estado', isEqualTo: 'programado')
            .get(const GetOptions(source: Source.cache));
      }

      // Normalizar la fecha para comparar solo día, mes y año
      final targetDate = DateTime(date.year, date.month, date.day);

      return snapshot.docs
          .map((doc) => WalkMapper.fromMap(doc.id, doc.data()))
          .where((walk) {
            final walkDate = DateTime(
              walk.fechaPaseo.year,
              walk.fechaPaseo.month,
              walk.fechaPaseo.day,
            );
            return walkDate.isAtSameMomentAs(targetDate);
          })
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<List<Walk>> getWalksByPaseadorIdAndDateAllStatus(String paseadorId, DateTime date) async {
    try {
      // Obtener todos los paseos (sin filtrar por estado) y filtrar por fecha en memoria
      // Usar Source.serverAndCache para incluir datos locales pendientes de sincronización
      // Si falla, intentar con Source.cache para obtener solo datos locales
      QuerySnapshot<Map<String, dynamic>> snapshot;
      try {
        snapshot = await _firestore
            .collection(FirestorePaths.paseosPath(paseadorId))
            .get(const GetOptions(source: Source.serverAndCache));
      } catch (e) {
        // Si falla (sin conexión), usar solo caché local
        snapshot = await _firestore
            .collection(FirestorePaths.paseosPath(paseadorId))
            .get(const GetOptions(source: Source.cache));
      }

      // Normalizar la fecha para comparar solo día, mes y año
      final targetDate = DateTime(date.year, date.month, date.day);

      return snapshot.docs
          .map((doc) => WalkMapper.fromMap(doc.id, doc.data()))
          .where((walk) {
            final walkDate = DateTime(
              walk.fechaPaseo.year,
              walk.fechaPaseo.month,
              walk.fechaPaseo.day,
            );
            return walkDate.isAtSameMomentAs(targetDate);
          })
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
      // Obtener todos los paseos y filtrar por rango de fechas en memoria
      final snapshot = await _firestore
          .collection(FirestorePaths.paseosPath(paseadorId))
          .get();

      // Normalizar las fechas para comparar solo día, mes y año
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
      // En modo offline, Firestore puede lanzar errores de red
      // pero los datos se guardan localmente. Verificamos si es un error de red.
      if (e.toString().contains('network') || 
          e.toString().contains('UNAVAILABLE') ||
          e.toString().contains('DEADLINE_EXCEEDED')) {
        // En modo offline, la escritura se encola y se sincronizará cuando haya conexión
        // Consideramos esto como éxito porque los datos están guardados localmente
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
