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
  
  // Acá inicializamos Firebase con las opciones de la plataforma
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // En Android activamos la persistencia offline para que funcione sin internet
  if (Platform.isAndroid) {
    try {
      final firestore = FirebaseFirestore.instance;
      // Hay que configurar esto antes de tocar Firestore
      firestore.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
    } catch (e) {
      // Si ya estaba habilitada, no hacemos nada
      print('Persistencia offline: $e');
    }
  }
  
      // Formato de fecha.
      await initializeDateFormatting('es_ES', null);
      
      // Servicio de notificaciones locales para los recordatorios de paseo
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
          // Después del login volvemos al inicio (índice 0) para que no quede en otra pestaña
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
