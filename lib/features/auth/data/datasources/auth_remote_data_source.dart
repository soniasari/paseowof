import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/constants/firestore_paths.dart';
import '../../domain/entities/walker.dart';
import '../mappers/walker_mapper.dart';

abstract class AuthRemoteDataSource {
  Future<User> signInWithEmailAndPassword({
    required String email,
    required String password,
  });
  
  Future<User> createUserWithEmailAndPassword({
    required String email,
    required String password,
  });
  
  Future<void> saveWalkerToFirestore(Walker walker);
  
  Future<Walker?> getWalkerById(String walkerId);
  
  Future<void> signOut();
  
  Future<void> sendPasswordResetEmail({required String email});
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  AuthRemoteDataSourceImpl({
    required FirebaseAuth auth,
    required FirebaseFirestore firestore,
  })  : _auth = auth,
        _firestore = firestore;

  @override
  Future<User> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential.user!;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<User> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential.user!;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> saveWalkerToFirestore(Walker walker) async {
    try {
      final walkerMap = WalkerMapper.toMap(walker);
      await _firestore
          .collection(FirestorePaths.paseadores)
          .doc(walker.id)
          .set(walkerMap, SetOptions(merge: false));
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
  Future<Walker?> getWalkerById(String walkerId) async {
    try {
      final doc = await _firestore
          .collection(FirestorePaths.paseadores)
          .doc(walkerId)
          .get();

      if (!doc.exists) {
        return null;
      }

      return WalkerMapper.fromMap(walkerId, doc.data()!);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> signOut() async {
    await _auth.signOut();
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      rethrow;
    }
  }
}
