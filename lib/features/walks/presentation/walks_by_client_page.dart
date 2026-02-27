import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_input.dart';
import 'package:paseowof/features/walks/domain/entities/walk.dart';
import 'package:paseowof/features/owners_pets/domain/entities/owner.dart';
import 'package:paseowof/features/auth/presentation/providers/auth_providers.dart';
import 'package:paseowof/features/owners_pets/presentation/providers/owner_pet_providers.dart';
import 'controllers/walks_by_client_form_controller.dart';
import 'providers/walks_providers.dart';

class WalksByClientPage extends ConsumerStatefulWidget {
  const WalksByClientPage({super.key});

  @override
  ConsumerState<WalksByClientPage> createState() => _WalksByClientPageState();
}

class _WalksByClientPageState extends ConsumerState<WalksByClientPage> {
  final TextEditingController _fechaInicioController = TextEditingController();
  final TextEditingController _fechaFinController = TextEditingController();

  @override
  void dispose() {
    _fechaInicioController.dispose();
    _fechaFinController.dispose();
    super.dispose();
  }

  Future<void> _selectFechaInicio() async {
    if (!mounted) return;
    
    final formState = ref.read(walksByClientFormControllerProvider);
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: formState.fechaInicio ?? now,
      firstDate: DateTime(2020),
      lastDate: now,
    );

    if (picked != null && mounted) {
      final controller = ref.read(walksByClientFormControllerProvider.notifier);
      controller.setFechaInicio(picked);
      _fechaInicioController.text = DateFormat('dd/MM/yyyy').format(picked);
      
      // Ejecutar búsqueda automáticamente si ambas fechas están seleccionadas
      if (formState.fechaFin != null) {
        _executeSearch();
      }
    }
  }

  Future<void> _selectFechaFin() async {
    if (!mounted) return;
    
    final formState = ref.read(walksByClientFormControllerProvider);
    final now = DateTime.now();
    final initialDate = formState.fechaFin ?? formState.fechaInicio ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: formState.fechaInicio ?? DateTime(2020),
      lastDate: now,
    );

    if (picked != null && mounted) {
      final controller = ref.read(walksByClientFormControllerProvider.notifier);
      controller.setFechaFin(picked);
      _fechaFinController.text = DateFormat('dd/MM/yyyy').format(picked);
      
      // Validar y buscar automáticamente si ambas fechas están seleccionadas
      if (formState.fechaInicio != null) {
        if (picked.isBefore(formState.fechaInicio!)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('La fecha de fin debe ser posterior a la fecha de inicio'),
              backgroundColor: AppColors.error,
            ),
          );
          return;
        }
        
        // Ejecutar búsqueda automáticamente
        _executeSearch();
      }
    }
  }

  void _executeSearch() {
    final authState = ref.read(authControllerProvider);
    final user = authState.value;
    final formState = ref.read(walksByClientFormControllerProvider);
    if (user != null && formState.fechaInicio != null && formState.fechaFin != null) {
      ref.invalidate(walksByDateRangeProvider(
        WalksByDateRangeParams(
          paseadorId: user.uid,
          fechaInicio: formState.fechaInicio!,
          fechaFin: formState.fechaFin!,
        ),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(walksByClientFormControllerProvider);
    final authState = ref.watch(authControllerProvider);
    final user = authState.value;
    final paseadorId = user?.uid ?? '';

    // Obtener paseos del paseador con filtro de fechas
    final fechaInicio = formState.fechaInicio ?? DateTime(2020, 1, 1);
    final fechaFin = formState.fechaFin ?? DateTime.now();
    
    final walksAsync = ref.watch(walksByDateRangeProvider(
      WalksByDateRangeParams(
        paseadorId: paseadorId,
        fechaInicio: fechaInicio,
        fechaFin: fechaFin,
      ),
    ));

    // Obtener propietarios
    final ownersAsync = ref.watch(ownersListProvider(paseadorId));

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Paseos por Cliente',
          style: TextStyle(
            color: AppColors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: const Color(0xFF0A8F68),
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Filtros
            Container(
              padding: const EdgeInsets.all(16.0),
              color: AppColors.white,
              child: Column(
                children: [
                  // Filtros de fecha
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: _selectFechaInicio,
                          child: AbsorbPointer(
                            child: AppInput(
                              icon: Icons.calendar_today_outlined,
                              label: 'Fecha Inicio',
                              controller: _fechaInicioController,
                              enabled: false,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: _selectFechaFin,
                          child: AbsorbPointer(
                            child: AppInput(
                              icon: Icons.calendar_today_outlined,
                              label: 'Fecha Fin',
                              controller: _fechaFinController,
                              enabled: false,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Filtro de cliente
                  ownersAsync.when(
                    data: (owners) {
                      final formStateOwner = ref.watch(walksByClientFormControllerProvider);
                      return DropdownButtonFormField<String>(
                        value: formStateOwner.selectedOwnerId,
                        decoration: InputDecoration(
                          labelText: 'Cliente',
                          labelStyle: TextStyle(
                            color: formStateOwner.selectedOwnerId == null
                                ? Colors.grey.shade500
                                : AppColors.button.withOpacity(0.8),
                            fontSize: formStateOwner.selectedOwnerId == null ? 16 : 12,
                            fontWeight: FontWeight.w500,
                          ),
                          floatingLabelBehavior: FloatingLabelBehavior.auto,
                          prefixIcon: Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: Icon(
                              Icons.person_outline,
                              color: Colors.grey.shade400,
                              size: 20,
                            ),
                          ),
                          prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                          contentPadding: const EdgeInsets.only(top: 24, bottom: 8),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(
                              color: Colors.grey.shade300,
                              width: 1.0,
                            ),
                          ),
                          focusedBorder: const UnderlineInputBorder(
                            borderSide: BorderSide(
                              color: AppColors.button,
                              width: 2.0,
                            ),
                          ),
                          isDense: true,
                        ),
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('Todos los clientes'),
                          ),
                          ...owners.map((owner) {
                            return DropdownMenuItem<String>(
                              value: owner.id,
                              child: Text(owner.nombre),
                            );
                          }),
                        ],
                        onChanged: (value) {
                          final controller = ref.read(walksByClientFormControllerProvider.notifier);
                          controller.setSelectedOwnerId(value);
                        },
                        hint: const Text('Selecciona un cliente'),
                      );
                    },
                    loading: () => const SizedBox(
                      height: 48,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (error, stack) => const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
            // Lista de resultados
            Expanded(
              child: walksAsync.when(
                data: (walks) {
                  return ownersAsync.when(
                    data: (owners) {
                      final formStateFilter = ref.watch(walksByClientFormControllerProvider);
                      // Filtrar por cliente si está seleccionado
                      List<Walk> filteredWalks = walks;
                      if (formStateFilter.selectedOwnerId != null) {
                        filteredWalks = walks.where((walk) => walk.propietarioId == formStateFilter.selectedOwnerId).toList();
                      }

                      // Agrupar paseos por propietario
                      final walksByOwner = <String, List<Walk>>{};
                      for (final walk in filteredWalks) {
                        if (!walksByOwner.containsKey(walk.propietarioId)) {
                          walksByOwner[walk.propietarioId] = [];
                        }
                        walksByOwner[walk.propietarioId]!.add(walk);
                      }

                      // Ordenar paseos por fecha (más recientes primero)
                      for (final ownerId in walksByOwner.keys) {
                        walksByOwner[ownerId]!.sort((a, b) => b.fechaPaseo.compareTo(a.fechaPaseo));
                      }

                      if (walksByOwner.isEmpty) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32.0),
                            child: Text(
                              'No hay paseos registrados para los filtros seleccionados',
                              style: TextStyle(
                                fontSize: 16,
                                color: AppColors.textGrey,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.all(16.0),
                        itemCount: walksByOwner.length,
                        itemBuilder: (context, index) {
                          final ownerId = walksByOwner.keys.elementAt(index);
                          final owner = owners.firstWhere(
                            (o) => o.id == ownerId,
                            orElse: () => Owner(
                              id: ownerId,
                              paseadorId: paseadorId,
                              nombre: 'Cliente no encontrado',
                              ci: '',
                              telefono: '',
                              direccion: '',
                              email: '',
                              activo: true,
                              fechaRegistro: DateTime.now(),
                            ),
                          );
                          final ownerWalks = walksByOwner[ownerId]!;

                          return _buildOwnerCard(context, owner, ownerWalks);
                        },
                      );
                    },
                    loading: () => const Center(
                      child: CircularProgressIndicator(),
                    ),
                    error: (error, stack) => Center(
                      child: Text(
                        'Error al cargar propietarios: ${error.toString()}',
                        style: const TextStyle(
                          color: AppColors.error,
                        ),
                      ),
                    ),
                  );
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(),
                ),
                error: (error, stack) => Center(
                  child: Text(
                    'Error al cargar paseos: ${error.toString()}',
                    style: const TextStyle(
                      color: AppColors.error,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOwnerCard(BuildContext context, Owner owner, List<Walk> walks) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.secondary,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header del cliente
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.secondary.withOpacity(0.3),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person,
                    color: AppColors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        owner.nombre,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      if (owner.ci.isNotEmpty)
                        Text(
                          'CI: ${owner.ci.replaceAll(' LP', '')}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textGrey,
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${walks.length} ${walks.length == 1 ? 'paseo' : 'paseos'}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Lista de paseos
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: walks.length,
            itemBuilder: (context, index) {
              final walk = walks[index];
              final isLast = index == walks.length - 1;
              
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: isLast
                      ? null
                      : Border(
                          bottom: BorderSide(
                            color: AppColors.secondary.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                ),
                child: Row(
                  children: [
                    // Icono de fecha
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _getStatusColor(walk.estado).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.calendar_today,
                        color: _getStatusColor(walk.estado),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Información del paseo
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.access_time,
                                size: 14,
                                color: AppColors.textGrey,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                DateFormat('dd/MM/yyyy').format(walk.fechaPaseo),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textDark,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${walk.horaInicio} - ${walk.horaFin ?? "N/A"}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textGrey,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.timer,
                                size: 14,
                                color: AppColors.textGrey,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                walk.duracionMinutos != null
                                    ? '${walk.duracionMinutos} minutos'
                                    : 'Duración no especificada',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textGrey,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Estado del paseo
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getStatusColor(walk.estado).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _getStatusText(walk.estado),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _getStatusColor(walk.estado),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String estado) {
    switch (estado.toLowerCase()) {
      case 'completado':
        return AppColors.success;
      case 'cancelado':
        return AppColors.error;
      case 'programado':
        return AppColors.button;
      case 'reprogramado':
        return AppColors.warning;
      default:
        return AppColors.textGrey;
    }
  }

  String _getStatusText(String estado) {
    switch (estado.toLowerCase()) {
      case 'completado':
        return 'Completado';
      case 'cancelado':
        return 'Cancelado';
      case 'programado':
        return 'Programado';
      case 'reprogramado':
        return 'Reprogramado';
      default:
        return estado;
    }
  }
}

