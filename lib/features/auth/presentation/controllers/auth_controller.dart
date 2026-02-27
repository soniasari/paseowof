import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/walker.dart';
import '../../domain/repositories/auth_repository.dart';

class AuthController extends StateNotifier<AsyncValue<User?>> {
  AuthController(this._auth, this._repository, this._ref)
      : super(const AsyncValue.loading()) {
    // Inicializar con el usuario actual inmediatamente para evitar delay
    final currentUser = _auth.currentUser;
    if (currentUser != null) {
      state = AsyncValue.data(currentUser);
    } else {
      state = const AsyncValue.data(null);
    }
    
    // Escuchar cambios de autenticación con un pequeño delay para evitar loops
    Future.microtask(() {
      if (!mounted) return;
      
      _subscription = _auth.authStateChanges().listen((user) {
        if (mounted) {
          // Solo actualizar si el usuario realmente cambió
          final currentState = state.value;
          if (currentState?.uid != user?.uid) {
            state = AsyncValue.data(user);
          }
        }
      });
    });
    
    // Cancelar suscripción cuando el provider se destruya
    _ref.onDispose(() {
      _subscription?.cancel();
    });
  }

  final FirebaseAuth _auth;
  final AuthRepository _repository;
  final Ref _ref;
  StreamSubscription<User?>? _subscription;

  // Obtener usuario actual
  User? get currentUser => _auth.currentUser;

  // Login con email y contraseña
  Future<void> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      state = const AsyncValue.loading();
      final user = await _repository.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      state = AsyncValue.data(user);
    } on FirebaseAuthException catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      rethrow;
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      rethrow;
    }
  }

  // Registro con email, contraseña y datos del walker
  Future<void> registerWithEmailAndPassword({
    required String email,
    required String password,
    required Walker walker,
  }) async {
    try {
      state = const AsyncValue.loading();
      final user = await _repository.registerWithEmailAndPassword(
        email: email,
        password: password,
        walker: walker,
      );
      state = AsyncValue.data(user);
    } on FirebaseAuthException catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      rethrow;
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      rethrow;
    }
  }

  // Obtener walker actual
  Future<Walker?> getCurrentWalker() async {
    return await _repository.getCurrentWalker();
  }

  // Cerrar sesión
  Future<void> signOut() async {
    try {
      await _repository.signOut();
      state = const AsyncValue.data(null);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      rethrow;
    }
  }

  // Enviar correo de recuperación de contraseña
  Future<void> sendPasswordResetEmail({required String email}) async {
    try {
      await _repository.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      rethrow;
    }
  }
}
