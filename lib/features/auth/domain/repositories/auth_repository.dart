import 'package:firebase_auth/firebase_auth.dart';
import '../entities/walker.dart';

abstract class AuthRepository {
  Future<User> signInWithEmailAndPassword({
    required String email,
    required String password,
  });

  Future<User> registerWithEmailAndPassword({
    required String email,
    required String password,
    required Walker walker,
  });

  Future<Walker?> getCurrentWalker();

  Future<void> signOut();
  
  Future<void> sendPasswordResetEmail({required String email});
}
