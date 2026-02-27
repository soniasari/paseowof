import 'package:firebase_auth/firebase_auth.dart';
import '../../domain/entities/walker.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_data_source.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _remoteDataSource;

  AuthRepositoryImpl(this._remoteDataSource);

  @override
  Future<User> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final user = await _remoteDataSource.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return user;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<User> registerWithEmailAndPassword({
    required String email,
    required String password,
    required Walker walker,
  }) async {
    try {
      // 1. Crear usuario en Firebase Auth
      final user = await _remoteDataSource.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // 2. Crear Walker con el UID del usuario
      final walkerWithId = Walker(
        id: user.uid,
        nombre: walker.nombre,
        ci: walker.ci,
        email: walker.email,
        telefono: walker.telefono,
        fechaRegistro: DateTime.now(),
        activo: true,
      );

      // 3. Guardar Walker en Firestore
      await _remoteDataSource.saveWalkerToFirestore(walkerWithId);

      return user;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<Walker?> getCurrentWalker() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      return await _remoteDataSource.getWalkerById(user.uid);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> signOut() async {
    await _remoteDataSource.signOut();
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {
    try {
      await _remoteDataSource.sendPasswordResetEmail(email: email);
    } catch (e) {
      rethrow;
    }
  }
}
