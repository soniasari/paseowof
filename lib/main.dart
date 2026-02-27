import 'dart:io' show Platform;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/services/local_notification_service.dart';
import 'features/auth/presentation/login_page.dart';
import 'features/home/presentation/home_page.dart';
import 'features/auth/presentation/providers/auth_providers.dart';
import 'features/home/presentation/providers/home_providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializar Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Habilitar persistencia offline solo para Android
  if (Platform.isAndroid) {
    try {
      final firestore = FirebaseFirestore.instance;
      // Configurar persistencia offline ANTES de cualquier operación
      firestore.settings = const Settings(
        persistenceEnabled: true, // Habilitar persistencia offline
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED, // Caché ilimitado
      );
    } catch (e) {
      // Si la persistencia ya está habilitada, ignorar el error
      print('Persistencia offline: $e');
    }
  }
  
      // Inicializar formato de fecha para español
      await initializeDateFormatting('es_ES', null);
      
      // Inicializar servicio de notificaciones locales
      await LocalNotificationService().initialize();
      
      runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PaseoWof',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);

    return authState.when(
      data: (user) {
        if (user != null) {
          // Resetear el índice de navegación a 0 (home) cuando se autentica
          // Esto asegura que siempre se muestre la pantalla de inicio después del login
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(homeNavigationControllerProvider.notifier).setIndex(0);
          });
          return const HomePage();
        }
        return const LoginPage();
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => const LoginPage(),
    );
  }
}
