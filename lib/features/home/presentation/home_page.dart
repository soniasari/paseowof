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
import '../../walks/presentation/walk_detail_page.dart';
import '../../walks/presentation/widgets/cancel_walk_dialog.dart';
import '../../walks/domain/entities/walk.dart';
import '../../walks/presentation/providers/walks_providers.dart';
import '../../owners_pets/presentation/providers/owner_pet_providers.dart';
import '../../owners_pets/domain/entities/pet.dart';
import 'package:intl/intl.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walkerAsync = ref.watch(currentWalkerProvider);
    final currentIndex = ref.watch(homeNavigationControllerProvider);

    // Según el tab: inicio, reportes o perfil
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.homeGradientTop,
              AppColors.homeGradientBottom,
            ],
          ),
        ),
        child: currentScreen,
      ),
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
            // Saludo
            _buildWelcomeCard(context, ref, walkerAsync),
            const SizedBox(height: 24),

            // Título
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

            // Las 4 opciones del menú
            _buildOptionsGrid(context, ref),
            const SizedBox(height: 24),

            // Paseos de hoy
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
        color: AppColors.button,
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

    // Solo día/mes/año para comparar con los paseos
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
              const Expanded(
                child: Text(
                  'Agenda de Hoy',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              walksAsync.when(
                data: (walks) {
                  final pendientes = walks.where((w) => w.estado == 'programado').length;
                  if (pendientes == 0) return const SizedBox.shrink();
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.secondary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$pendientes pendientes',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.button,
                      ),
                    ),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          walksAsync.when(
            data: (walks) {
              final ordenados = List<Walk>.from(walks)
                ..sort((a, b) {
                  final minA = _horaAMinutos(a.horaInicio);
                  final minB = _horaAMinutos(b.horaInicio);
                  return minA.compareTo(minB);
                });

              if (ordenados.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'No tienes paseos programados para hoy. ¡No olvides el agua!',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textGrey,
                    ),
                  ),
                );
              }

              return Column(
                children: [
                  for (int i = 0; i < ordenados.length; i++) ...[
                    if (i > 0) Divider(height: 1, color: Colors.grey.shade300),
                    _buildWalkRow(context, ref, ordenados[i], user.uid),
                  ],
                ],
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

  Widget _buildWalkRow(BuildContext context, WidgetRef ref, Walk walk, String paseadorId) {
    final walkPetsAsync = ref.watch(walkPetsProvider(
      WalkPetsParams(paseadorId: paseadorId, walkId: walk.id),
    ));
    final petsAsync = ref.watch(petsListProvider(paseadorId));
    final timeStr = _formatHora(walk.horaInicio);
    final isActive = walk.estado == 'programado';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: InkWell(
        onLongPress: walk.estado == 'programado'
            ? () {
                showModalBottomSheet(
                  context: context,
                  builder: (ctx) => SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          leading: const Icon(Icons.check_circle_outline),
                          title: const Text('Marcar atendido'),
                          onTap: () {
                            Navigator.pop(ctx);
                            _handleMarkAsCompleted(context, ref, walk, paseadorId);
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.cancel_outlined),
                          title: const Text('Cancelar paseo'),
                          onTap: () {
                            Navigator.pop(ctx);
                            _handleCancelWalk(context, ref, walk, paseadorId);
                          },
                        ),
                      ],
                    ),
                  ),
                );
              }
            : null,
        child: Row(
          children: [
          Expanded(
            child: walkPetsAsync.when(
              data: (walkPets) {
                if (walkPets.isEmpty) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Paseo', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                      const SizedBox(height: 2),
                      Text('— • $timeStr', style: const TextStyle(fontSize: 13, color: AppColors.textGrey)),
                    ],
                  );
                }
                final firstPet = walkPets.first;
                final nombreMascota = firstPet.nombreCanino;
                return petsAsync.when(
                  data: (pets) {
                    Pet? pet;
                    try {
                      pet = pets.firstWhere((p) => p.id == firstPet.caninoId);
                    } catch (_) {
                      pet = null;
                    }
                    final raza = pet?.raza ?? '—';
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          nombreMascota,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$raza • $timeStr',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textGrey,
                          ),
                        ),
                      ],
                    );
                  },
                  loading: () => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(nombreMascota, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                      Text('— • $timeStr', style: const TextStyle(fontSize: 13, color: AppColors.textGrey)),
                    ],
                  ),
                  error: (_, __) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(nombreMascota, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                      Text('— • $timeStr', style: const TextStyle(fontSize: 13, color: AppColors.textGrey)),
                    ],
                  ),
                );
              },
              loading: () => Text(timeStr, style: const TextStyle(fontSize: 13, color: AppColors.textGrey)),
              error: (_, __) => Text(timeStr, style: const TextStyle(fontSize: 13, color: AppColors.textGrey)),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: isActive ? AppColors.button.withOpacity(0.2) : const Color(0xFFE0E0E0),
            shape: const CircleBorder(),
            elevation: 0,
            child: InkWell(
              onTap: isActive ? () => _handleRescheduleWalk(context, ref, walk, paseadorId) : null,
              customBorder: const CircleBorder(),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Icon(
                  isActive ? Icons.arrow_forward_ios : Icons.lock,
                  size: 16,
                  color: isActive ? AppColors.button : const Color(0xFF9E9E9E),
                ),
              ),
            ),
          ),
        ],
        ),
      ),
    );
  }

  String _formatHora(String hora) {
    final partes = hora.split(':');
    if (partes.length < 2) return hora;
    final h = int.tryParse(partes[0]) ?? 0;
    final m = int.tryParse(partes[1]) ?? 0;
    final dt = DateTime(2000, 1, 1, h, m);
    return DateFormat('hh:mm a', 'es').format(dt);
  }

  Future<void> _handleMarkAsCompleted(BuildContext context, WidgetRef ref, Walk walk, String paseadorId) async {
    if (!context.mounted) return;

    try {
      await ref.read(walksControllerProvider.notifier).updateWalkStatus(
        paseadorId: paseadorId,
        walkId: walk.id,
        estado: 'completado',
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Paseo marcado como atendido'),
            backgroundColor: AppColors.success,
          ),
        );
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

    // Va al detalle, ahí se reprograma o cancela
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WalkDetailPage(
          walk: walk,
          paseadorId: paseadorId,
        ),
      ),
    );

    // Refresco la lista
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

    final motivo = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return CancelWalkDialog(
          onCancel: () => Navigator.pop(dialogContext, null),
          onConfirm: (motivo) => Navigator.pop(dialogContext, motivo),
        );
      },
    );

    if (motivo == null || !context.mounted) return;

    try {
      await ref.read(walksControllerProvider.notifier).updateWalkStatus(
        paseadorId: paseadorId,
        walkId: walk.id,
        estado: 'cancelado',
        motivoCancelacion: motivo,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Paseo cancelado'),
            backgroundColor: AppColors.error,
          ),
        );
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

int _horaAMinutos(String hora) {
  final partes = hora.split(':');
  if (partes.length < 2) return 0;
  final h = int.tryParse(partes[0]) ?? 0;
  final m = int.tryParse(partes[1]) ?? 0;
  return h * 60 + m;
}

