import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/dependency_injection.dart';
import '../controllers/auth_controller.dart';
import '../controllers/login_form_controller.dart';
import '../controllers/register_form_controller.dart';
import '../../domain/entities/walker.dart';

// Re-exportar providers de DI para mantener compatibilidad
export '../../../../core/di/dependency_injection.dart' show firebaseAuthProvider, firebaseFirestoreProvider, authRepositoryProvider;

// Provider del AuthController - mantener vivo durante toda la app
final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<User?>>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  final repository = ref.watch(authRepositoryProvider);
  final controller = AuthController(auth, repository, ref);
  return controller;
});

// Provider del usuario actual
final currentUserProvider = StreamProvider<User?>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  return auth.authStateChanges();
});

// Provider del walker actual - solo se ejecuta si hay usuario autenticado
final currentWalkerProvider = FutureProvider.autoDispose<Walker?>((ref) async {
  // Obtener el usuario directamente de FirebaseAuth para evitar dependencias circulares
  final user = FirebaseAuth.instance.currentUser;
  
  // Si no hay usuario, retornar null inmediatamente sin hacer consulta
  if (user == null) {
    return null;
  }
  
  final repository = ref.watch(authRepositoryProvider);
  return await repository.getCurrentWalker();
});

// Provider del LoginFormController
final loginFormControllerProvider =
    StateNotifierProvider<LoginFormController, LoginFormState>((ref) {
  return LoginFormController();
});

// Provider del RegisterFormController
final registerFormControllerProvider =
    StateNotifierProvider<RegisterFormController, RegisterFormState>((ref) {
  return RegisterFormController();
});
