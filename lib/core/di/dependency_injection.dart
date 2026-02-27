import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/data/datasources/auth_remote_data_source.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/owners_pets/data/datasources/owner_pet_remote_data_source.dart';
import '../../features/owners_pets/data/repositories/owner_pet_repository_impl.dart';
import '../../features/owners_pets/domain/repositories/owner_pet_repository.dart';
import '../../features/walks/data/datasources/walks_remote_data_source.dart';
import '../../features/walks/data/repositories/walks_repository_impl.dart';
import '../../features/walks/domain/repositories/walks_repository.dart';

/// Capa de Inyección de Dependencias
/// Centraliza la configuración de providers para cumplir con arquitectura limpia
/// La capa de presentación solo debe depender de esta capa, no directamente de data

// ========== Firebase Providers ==========
final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

final firebaseFirestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

// ========== Auth Layer ==========
final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  final firestore = ref.watch(firebaseFirestoreProvider);
  return AuthRemoteDataSourceImpl(auth: auth, firestore: firestore);
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final dataSource = ref.watch(authRemoteDataSourceProvider);
  return AuthRepositoryImpl(dataSource);
});

// ========== Owners & Pets Layer ==========
final ownerPetRemoteDataSourceProvider = Provider<OwnerPetRemoteDataSource>((ref) {
  final firestore = ref.watch(firebaseFirestoreProvider);
  return OwnerPetRemoteDataSourceImpl(firestore: firestore);
});

final ownerPetRepositoryProvider = Provider<OwnerPetRepository>((ref) {
  final dataSource = ref.watch(ownerPetRemoteDataSourceProvider);
  return OwnerPetRepositoryImpl(dataSource);
});

// ========== Walks Layer ==========
final walksRemoteDataSourceProvider = Provider<WalksRemoteDataSource>((ref) {
  final firestore = ref.watch(firebaseFirestoreProvider);
  return WalksRemoteDataSourceImpl(firestore: firestore);
});

final walksRepositoryProvider = Provider<WalksRepository>((ref) {
  final dataSource = ref.watch(walksRemoteDataSourceProvider);
  return WalksRepositoryImpl(dataSource);
});

