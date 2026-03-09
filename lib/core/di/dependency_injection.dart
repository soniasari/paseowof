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
import '../../features/walks/domain/use_cases/complete_walk_with_track_use_case.dart';
import '../../features/walks/domain/use_cases/update_walk_status_use_case.dart';
import '../../features/walks/data/services/walk_location_stream_service.dart';
import '../../features/walks/data/services/walk_track_filter_service.dart';
import '../services/location_permission_service.dart';

// Dependencias: Firebase, repos. La UI usa esto, no toca data a mano.

// Firebase
final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

final firebaseFirestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

// Auth (login, registro, paseador)
final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  final firestore = ref.watch(firebaseFirestoreProvider);
  return AuthRemoteDataSourceImpl(auth: auth, firestore: firestore);
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final dataSource = ref.watch(authRemoteDataSourceProvider);
  return AuthRepositoryImpl(dataSource);
});

// Propietarios y caninos
final ownerPetRemoteDataSourceProvider = Provider<OwnerPetRemoteDataSource>((ref) {
  final firestore = ref.watch(firebaseFirestoreProvider);
  return OwnerPetRemoteDataSourceImpl(firestore: firestore);
});

final ownerPetRepositoryProvider = Provider<OwnerPetRepository>((ref) {
  final dataSource = ref.watch(ownerPetRemoteDataSourceProvider);
  return OwnerPetRepositoryImpl(dataSource);
});

// Paseos
final walksRemoteDataSourceProvider = Provider<WalksRemoteDataSource>((ref) {
  final firestore = ref.watch(firebaseFirestoreProvider);
  return WalksRemoteDataSourceImpl(firestore: firestore);
});

final walksRepositoryProvider = Provider<WalksRepository>((ref) {
  final dataSource = ref.watch(walksRemoteDataSourceProvider);
  return WalksRepositoryImpl(dataSource);
});

// Para marcar paseo completado o cancelado
final updateWalkStatusUseCaseProvider = Provider<UpdateWalkStatusUseCase>((ref) {
  final repository = ref.watch(walksRepositoryProvider);
  return UpdateWalkStatusUseCase(repository);
});

// Paseo en curso: permisos, flujo de ubicación y filtros
final locationPermissionServiceProvider = Provider<LocationPermissionService>((ref) {
  return LocationPermissionService();
});

final walkLocationStreamServiceProvider = Provider<WalkLocationStreamService>((ref) {
  return WalkLocationStreamService();
});

final walkTrackFilterServiceProvider = Provider<WalkTrackFilterService>((ref) {
  return WalkTrackFilterService();
});

final completeWalkWithTrackUseCaseProvider = Provider<CompleteWalkWithTrackUseCase>((ref) {
  final repository = ref.watch(walksRepositoryProvider);
  return CompleteWalkWithTrackUseCase(repository);
});

