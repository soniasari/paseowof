import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/pages/notifications_test_page.dart';
import 'providers/auth_providers.dart';
import 'login_page.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walkerAsync = ref.watch(currentWalkerProvider);
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // "Mi" con outline (solo stroke, sin fill)
            Text(
              'Mi',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w300,
                foreground: Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 1.5
                  ..color = AppColors.white,
              ),
            ),
            const SizedBox(width: 4),
            // "Perfil" en blanco sólido
            const Text(
              'Perfil',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.white,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF0A8F68),
        foregroundColor: AppColors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Card de información del usuario
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.secondary,
                    width: 1,
                  ),
                ),
                child: walkerAsync.when(
                  data: (walker) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.person,
                              color: AppColors.white,
                              size: 32,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  walker?.nombre ?? 'Usuario',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textDark,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  walker?.email ?? '',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textGrey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (walker != null) ...[
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 16),
                        _buildInfoRow(
                          icon: Icons.badge,
                          label: 'CI',
                          value: walker.ci,
                        ),
                        const SizedBox(height: 12),
                        if (walker.telefono != null)
                          _buildInfoRow(
                            icon: Icons.phone,
                            label: 'Teléfono',
                            value: walker.telefono!,
                          ),
                      ],
                    ],
                  ),
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20.0),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (error, stack) => const Text(
                    'Error al cargar información',
                    style: TextStyle(color: AppColors.error),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Botón de Prueba de Notificaciones (solo en modo debug)
              if (const bool.fromEnvironment('dart.vm.product') == false)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const NotificationsTestPage(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.notifications_active),
                    label: const Text('Probar Notificaciones'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),

              // Botón de Cerrar Sesión
              AppButton(
                text: 'CERRAR SESIÓN',
                onPressed: authState.isLoading
                    ? null
                    : () => _handleSignOut(context, ref),
                isLoading: authState.isLoading,
                backgroundColor: AppColors.button,
                height: 48,
                icon: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.white, width: 1.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: const Icon(
                    Icons.logout,
                    size: 12,
                    color: AppColors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: AppColors.textGrey,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textGrey,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _handleSignOut(BuildContext context, WidgetRef ref) async {
    // Mostrar diálogo de confirmación
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cerrar Sesión'),
        content: const Text('¿Estás seguro de que deseas cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.button,
            ),
            child: const Text('Cerrar Sesión'),
          ),
        ],
      ),
    );

    // Si el usuario canceló, no hacer nada
    if (confirm != true) {
      return;
    }

    // Asegurarse de que el contexto sigue siendo válido
    if (!context.mounted) {
      return;
    }

    try {
      // Cerrar sesión
      await ref.read(authControllerProvider.notifier).signOut();
      
      // Limpiar el mensaje del formulario de login si existe
      try {
        ref.read(loginFormControllerProvider.notifier).clearMessage();
      } catch (_) {
        // Si el provider no existe aún, no hay problema
      }

      // Esperar un momento para asegurar que el estado se actualizó
      await Future.delayed(const Duration(milliseconds: 100));

      // Verificar que el contexto sigue siendo válido antes de navegar
      if (!context.mounted) {
        return;
      }

      // Navegar directamente al LoginPage y limpiar todo el stack
      // Usar Navigator.of(context) en lugar de rootNavigator para evitar problemas
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const LoginPage(),
        ),
        (route) => false,
      );
    } catch (e) {
      // Si hay un error, mostrar un mensaje
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cerrar sesión: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}

