import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/pressable_card.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../auth/domain/entities/walker.dart';
import '../../auth/presentation/profile_page.dart';
import '../../owners_pets/presentation/pets_list_page.dart';
import '../../owners_pets/presentation/owners_list_page.dart';
import 'reports_page.dart';
import 'providers/home_providers.dart';
import '../../walks/presentation/schedule_walk_page.dart';
import '../../walks/presentation/walks_history_page.dart';
import '../../walks/presentation/reschedule_walk_page.dart';
import '../../walks/domain/entities/walk.dart';
import '../../walks/presentation/providers/walks_providers.dart';
import '../../owners_pets/presentation/providers/owner_pet_providers.dart';
import '../../owners_pets/domain/entities/owner.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walkerAsync = ref.watch(currentWalkerProvider);
    final currentIndex = ref.watch(homeNavigationControllerProvider);

    // El AuthWrapper ya maneja la navegación automáticamente
    // No necesitamos verificar aquí para evitar reconstrucciones innecesarias

    // Mostrar diferentes pantallas según el índice seleccionado
    Widget currentScreen;
    switch (currentIndex) {
      case 0:
        currentScreen = _buildHomeContent(context, ref, walkerAsync);
        break;
      case 1:
        currentScreen = _buildReportsScreen(context, ref);
        break;
      case 2:
        currentScreen = const ProfilePage();
        break;
      default:
        currentScreen = _buildHomeContent(context, ref, walkerAsync);
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: currentScreen,
      bottomNavigationBar: _buildBottomNavigationBar(context, ref),
    );
  }

  Widget _buildHomeContent(BuildContext context, WidgetRef ref, AsyncValue<Walker?> walkerAsync) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card de Saludo
            _buildWelcomeCard(context, ref, walkerAsync),
            const SizedBox(height: 24),

            // Título "Administración Central"
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                'Administración Central',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Grid de 4 opciones
            _buildOptionsGrid(context, ref),
            const SizedBox(height: 24),

            // Card de Paseos Programados para Hoy
            _buildScheduledWalksCard(context, ref),
          ],
        ),
      ),
    );
  }

  Widget _buildReportsScreen(BuildContext context, WidgetRef ref) {
    return const ReportsPage();
  }

  Widget _buildWelcomeCard(BuildContext context, WidgetRef ref, AsyncValue<Walker?> walkerAsync) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0A8F68),
        borderRadius: BorderRadius.circular(16),
      ),
      child: walkerAsync.when(
        data: (walker) => Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hola, ${walker?.nombre ?? 'Usuario'}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tu centro de control para gestionar paseos y clientes.',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.white,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        loading: () => const Center(
          child: CircularProgressIndicator(
            color: AppColors.white,
          ),
        ),
        error: (error, stack) => const Text(
          'Hola, Usuario',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildOptionsGrid(BuildContext context, WidgetRef ref) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 0.95,
      children: [
        _buildOptionCard(
          context: context,
          ref: ref,
          cardId: 'registro_canes',
          icon: Icons.pets,
          iconColor: AppColors.primary,
          title: 'Registro de Canes',
          description: 'Gestiona la información de tus mascotas.',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const PetsListPage(),
              ),
            );
          },
        ),
        _buildOptionCard(
          context: context,
          ref: ref,
          cardId: 'registro_propietarios',
          icon: Icons.people,
          iconColor: AppColors.primary,
          title: 'Registro de Propietarios',
          description: 'Datos de contacto de los clientes.',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const OwnersListPage(),
              ),
            );
          },
        ),
        _buildOptionCard(
          context: context,
          ref: ref,
          cardId: 'programar_paseo',
          icon: Icons.calendar_today,
          iconColor: AppColors.primary,
          title: 'Programar Paseo',
          description: 'Agenda una nueva cita o paseo express.',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ScheduleWalkPage(),
              ),
            );
          },
        ),
        _buildOptionCard(
          context: context,
          ref: ref,
          cardId: 'historial_paseos',
          icon: Icons.assignment,
          iconColor: AppColors.primary,
          title: 'Historial de Paseos',
          description: 'Consulta ganancias, rutas y actividades pasadas.',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const WalksHistoryPage(),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildOptionCard({
    required BuildContext context,
    required WidgetRef ref,
    required String cardId,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return PressableCard(
      cardId: cardId,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: AppColors.white,
                size: 24,
              ),
            ),
            const SizedBox(height: 10),
            Flexible(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 6),
            Flexible(
              child: Text(
                description,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textGrey,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduledWalksCard(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final user = authState.value;
    
    if (user == null) {
      return const SizedBox.shrink();
    }

    // Normalizar la fecha actual (solo día, mes, año, sin hora)
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    final walksAsync = ref.watch(walksByDateAllStatusProvider(
      WalksByDateParams(paseadorId: user.uid, date: today),
    ));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Image.asset(
                'images/dog.png',
                width: 48,
                height: 48,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Paseos Programados para Hoy',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          walksAsync.when(
            data: (walks) {
              // Filtrar solo los paseos con estado "programado"
              final programados = walks.where((walk) => walk.estado == 'programado').toList();
              
              // Ordenar por hora de inicio de manera ascendente
              programados.sort((a, b) {
                final horaA = a.horaInicio.split(':');
                final horaB = b.horaInicio.split(':');
                final minutosA = int.parse(horaA[0]) * 60 + int.parse(horaA[1]);
                final minutosB = int.parse(horaB[0]) * 60 + int.parse(horaB[1]);
                return minutosA.compareTo(minutosB);
              });
              
              if (programados.isEmpty) {
                return const Text(
                  'No tienes paseos programados para hoy. ¡No olvides el agua!',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textGrey,
                  ),
                );
              }

              return Column(
                children: programados.map((walk) {
                  return _buildWalkCard(context, ref, walk, user.uid);
                }).toList(),
              );
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (error, stack) => Text(
              'Error al cargar paseos: ${error.toString()}',
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWalkCard(BuildContext context, WidgetRef ref, Walk walk, String paseadorId) {
    // Obtener información del propietario y perros
    final ownersAsync = ref.watch(ownersListProvider(paseadorId));
    final walkPetsAsync = ref.watch(walkPetsProvider(
      WalkPetsParams(paseadorId: paseadorId, walkId: walk.id),
    ));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.secondary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.secondary.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Información del paseo
          Row(
            children: [
              Icon(
                Icons.access_time,
                size: 16,
                color: AppColors.textGrey,
              ),
              const SizedBox(width: 8),
              Text(
                '${walk.horaInicio} - ${walk.horaFin ?? "N/A"}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ownersAsync.when(
            data: (owners) {
              final owner = owners.firstWhere(
                (o) => o.id == walk.propietarioId,
                orElse: () => owners.isNotEmpty ? owners.first : Owner(
                  id: '',
                  paseadorId: '',
                  nombre: 'Propietario no encontrado',
                  ci: '',
                  telefono: '',
                  direccion: '',
                  email: '',
                  activo: true,
                  fechaRegistro: DateTime.now(),
                ),
              );
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.person,
                        size: 16,
                        color: AppColors.textGrey,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          owner.nombre,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (walk.direccionRecogida != null && walk.direccionRecogida!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 16,
                          color: AppColors.textGrey,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            walk.direccionRecogida!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textGrey,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (error, stack) => const SizedBox.shrink(),
          ),
          walkPetsAsync.when(
            data: (walkPets) {
              if (walkPets.isEmpty) {
                return const SizedBox.shrink();
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.pets,
                        size: 16,
                        color: AppColors.textGrey,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          walkPets.map((wp) => wp.nombreCanino).join(', '),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textGrey,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (error, stack) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 12),
          // Botones de acción
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _handleRescheduleWalk(context, ref, walk, paseadorId),
                  icon: const Icon(Icons.update, size: 16),
                  label: const Text(
                    'Reprogramar',
                    style: TextStyle(fontSize: 12),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _handleMarkAsCompleted(context, ref, walk, paseadorId),
                  icon: const Icon(Icons.check_circle, size: 16),
                  label: const Text(
                    'Atendido',
                    style: TextStyle(fontSize: 12),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0A8F68),
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _handleCancelWalk(context, ref, walk, paseadorId),
                  icon: const Icon(Icons.cancel, size: 16),
                  label: const Text(
                    'Cancelar',
                    style: TextStyle(fontSize: 12),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handleMarkAsCompleted(BuildContext context, WidgetRef ref, Walk walk, String paseadorId) async {
    if (!context.mounted) return;

    try {
      // Usar el repositorio directamente para evitar problemas con autoDispose
      final repository = ref.read(walksRepositoryProvider);
      
      // Obtener el paseo actual
      final currentWalk = await repository.getWalkById(paseadorId, walk.id);
      if (currentWalk == null) {
        throw Exception('Paseo no encontrado');
      }

      // Actualizar el estado
      final updatedWalk = currentWalk.copyWith(
        estado: 'completado',
        fechaModificacion: DateTime.now(),
      );

      // Guardar el paseo actualizado
      await repository.saveWalk(updatedWalk);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Paseo marcado como atendido'),
            backgroundColor: AppColors.success,
          ),
        );
        // Invalidar el provider para refrescar la lista después de un microtask
        // Usar la fecha normalizada (solo día, mes, año) para que coincida con el filtro
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        Future.microtask(() {
          if (context.mounted) {
            ref.invalidate(walksByDateAllStatusProvider(
              WalksByDateParams(paseadorId: paseadorId, date: today),
            ));
          }
        });
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _handleRescheduleWalk(BuildContext context, WidgetRef ref, Walk walk, String paseadorId) async {
    if (!context.mounted) return;

    // Navegar a la página de reprogramación
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RescheduleWalkPage(
          walk: walk,
          paseadorId: paseadorId,
        ),
      ),
    );

    // Invalidar el provider para refrescar la lista después de un microtask
    if (context.mounted) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      Future.microtask(() {
        if (context.mounted) {
          ref.invalidate(walksByDateAllStatusProvider(
            WalksByDateParams(paseadorId: paseadorId, date: today),
          ));
        }
      });
    }
  }

  Future<void> _handleCancelWalk(BuildContext context, WidgetRef ref, Walk walk, String paseadorId) async {
    if (!context.mounted) return;

    // Mostrar diálogo para ingresar motivo de cancelación
    final motivo = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return _CancelWalkDialog(
          onCancel: () => Navigator.pop(dialogContext, null),
          onConfirm: (motivo) => Navigator.pop(dialogContext, motivo),
        );
      },
    );

    if (motivo == null || !context.mounted) return;

    try {
      // Usar el repositorio directamente para evitar problemas con autoDispose
      final repository = ref.read(walksRepositoryProvider);
      
      // Obtener el paseo actual
      final currentWalk = await repository.getWalkById(paseadorId, walk.id);
      if (currentWalk == null) {
        throw Exception('Paseo no encontrado');
      }

      // Actualizar el estado con el motivo de cancelación
      final updatedWalk = currentWalk.copyWith(
        estado: 'cancelado',
        fechaModificacion: DateTime.now(),
        motivoCancelacion: motivo,
      );

      // Guardar el paseo actualizado
      await repository.saveWalk(updatedWalk);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Paseo cancelado'),
            backgroundColor: AppColors.error,
          ),
        );
        // Invalidar el provider para refrescar la lista después de un microtask
        // Usar la fecha normalizada (solo día, mes, año) para que coincida con el filtro
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        Future.microtask(() {
          if (context.mounted) {
            ref.invalidate(walksByDateAllStatusProvider(
              WalksByDateParams(paseadorId: paseadorId, date: today),
            ));
          }
        });
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Widget _buildBottomNavigationBar(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(homeNavigationControllerProvider);
    
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) {
          ref.read(homeNavigationControllerProvider.notifier).setIndex(index);
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.button,
        unselectedItemColor: AppColors.textGrey,
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.normal,
          fontSize: 12,
        ),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Inicio',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assessment),
            label: 'Reportes',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}

// Widget separado para el diálogo de cancelación
class _CancelWalkDialog extends StatefulWidget {
  final VoidCallback onCancel;
  final Function(String) onConfirm;

  const _CancelWalkDialog({
    required this.onCancel,
    required this.onConfirm,
  });

  @override
  State<_CancelWalkDialog> createState() => _CancelWalkDialogState();
}

class _CancelWalkDialogState extends State<_CancelWalkDialog> {
  late final TextEditingController _motivoController;

  @override
  void initState() {
    super.initState();
    _motivoController = TextEditingController();
  }

  @override
  void dispose() {
    _motivoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Cancelar Paseo'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '¿Estás seguro de que deseas cancelar este paseo?',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _motivoController,
              decoration: const InputDecoration(
                labelText: 'Motivo de cancelación',
                hintText: 'Ingresa el motivo de la cancelación',
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding: EdgeInsets.all(12),
              ),
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              autofocus: true,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: widget.onCancel,
          child: const Text('No'),
        ),
        TextButton(
          onPressed: () {
            final motivoText = _motivoController.text.trim();
            if (motivoText.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Por favor, ingresa el motivo de cancelación'),
                  backgroundColor: AppColors.error,
                  duration: Duration(seconds: 2),
                ),
              );
              return;
            }
            widget.onConfirm(motivoText);
          },
          child: const Text('Sí, cancelar'),
        ),
      ],
    );
  }
}

