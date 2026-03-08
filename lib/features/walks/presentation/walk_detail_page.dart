// =============================================================================
// WALK DETAIL PAGE
// =============================================================================
// Pantalla de detalle de un paseo. Consume solo providers de Riverpod:
// [walkPetsProvider], [petsListProvider], [ownersListProvider] y
// [updateWalkStatusUseCaseProvider] para cancelar sin depender del
// WalksController (evita "controller after dispose" al cerrar la pantalla).
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/local_notification_service.dart';
import '../../owners_pets/domain/entities/owner.dart';
import '../../owners_pets/domain/entities/pet.dart';
import '../../owners_pets/presentation/providers/owner_pet_providers.dart';
import '../domain/entities/walk.dart';
import '../domain/entities/walk_pet.dart';
import 'providers/walks_providers.dart';
import 'reschedule_walk_page.dart';
import 'widgets/cancel_walk_dialog.dart';

/// Página de detalle de un paseo: datos del canino, dueño, horario y acciones
/// (reprogramar, cancelar, marcar completado).
class WalkDetailPage extends ConsumerStatefulWidget {
  final Walk walk;
  final String paseadorId;

  const WalkDetailPage({
    super.key,
    required this.walk,
    required this.paseadorId,
  });

  @override
  ConsumerState<WalkDetailPage> createState() => _WalkDetailPageState();
}

class _WalkDetailPageState extends ConsumerState<WalkDetailPage> {
  /// Formatea hora "HH:mm" a formato legible (ej. "09:00 AM").
  String _formatHora(String hora) {
    final partes = hora.split(':');
    if (partes.length < 2) return hora;
    final h = int.tryParse(partes[0]) ?? 0;
    final m = int.tryParse(partes[1]) ?? 0;
    final dt = DateTime(2000, 1, 1, h, m);
    return DateFormat('hh:mm a', 'es').format(dt);
  }

  /// Flujo de cancelación del paseo

  Future<void> _handleCancelWalk() async {
    if (!mounted) return;
    final motivo = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => CancelWalkDialog(
        onCancel: () => Navigator.pop(dialogContext, null),
        onConfirm: (motivo) => Navigator.pop(dialogContext, motivo),
      ),
    );
    if (motivo == null || !mounted) return;
    try {
      // Riverpod: uso del use case inyectado por DI 
      final useCase = ref.read(updateWalkStatusUseCaseProvider);
      await useCase.execute(
        paseadorId: widget.paseadorId,
        walkId: widget.walk.id,
        estado: 'cancelado',
        motivoCancelacion: motivo,
      );
      if (!mounted) return;
      // Notificaciones programadas del paseo se cancelan para no seguir mostrando recordatorios.
      try {
        final notificationService = LocalNotificationService();
        await notificationService.cancelNotification(widget.walk.id.hashCode.abs());
        await notificationService.cancelNotification(widget.walk.id.hashCode.abs() + 1);
      } catch (_) {}
      // Invalidar providers de Riverpod para que Home y listas reflejen el paseo cancelado.
      ref.invalidate(walksByDateProvider(WalksByDateParams(paseadorId: widget.paseadorId, date: widget.walk.fechaPaseo)));
      ref.invalidate(walksByDateAllStatusProvider(WalksByDateParams(paseadorId: widget.paseadorId, date: widget.walk.fechaPaseo)));
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final walkDate = DateTime(widget.walk.fechaPaseo.year, widget.walk.fechaPaseo.month, widget.walk.fechaPaseo.day);
      if (walkDate.isAtSameMomentAs(today)) {
        ref.invalidate(walksByDateAllStatusProvider(WalksByDateParams(paseadorId: widget.paseadorId, date: today)));
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.lock, color: AppColors.white, size: 20),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('Paseo Programado cancelado con éxito'),
              ),
            ],
          ),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    
    final walkPetsAsync = ref.watch(walkPetsProvider(
      WalkPetsParams(paseadorId: widget.paseadorId, walkId: widget.walk.id),
    ));
    final petsAsync = ref.watch(petsListProvider(widget.paseadorId));
    final ownersAsync = ref.watch(ownersListProvider(widget.paseadorId));

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text.rich(
          TextSpan(
            text: 'Paseo',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w500,
              color: AppColors.white,
            ),
            children: [
              TextSpan(
                text: 'Woow',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.white,
                ),
              ),
            ],
          ),
        ),
        centerTitle: true,
        backgroundColor: AppColors.button,
        foregroundColor: AppColors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                builder: (ctx) => SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.edit_calendar),
                        title: const Text('Reprogramar'),
                        onTap: () {
                          Navigator.pop(ctx);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => RescheduleWalkPage(
                                walk: widget.walk,
                                paseadorId: widget.paseadorId,
                              ),
                            ),
                          ).then((_) => setState(() {}));
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.cancel, color: AppColors.error),
                        title: const Text('Cancelar paseo', style: TextStyle(color: AppColors.error)),
                        onTap: () {
                          Navigator.pop(ctx);
                          _handleCancelWalk();
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Perro (foto, nombre, raza/edad)
            walkPetsAsync.when(
              data: (walkPets) {
                if (walkPets.isEmpty) {
                  return _buildDogSection(
                    petName: 'Paseo',
                    breedAge: '—',
                  );
                }
                final firstPet = walkPets.first;
                return petsAsync.when(
                  data: (pets) {
                    Pet? pet;
                    try {
                      pet = pets.firstWhere((p) => p.id == firstPet.caninoId);
                    } catch (_) {
                      pet = null;
                    }
                    final raza = pet?.raza ?? '—';
                    final edad = pet?.edad != null ? '${pet!.edad} años' : '';
                    final breedAge = [raza, if (edad.isNotEmpty) edad].join(', ');
                    return _buildDogSection(
                      petName: firstPet.nombreCanino,
                      breedAge: breedAge.isEmpty ? '—' : breedAge,
                    );
                  },
                  loading: () => _buildDogSection(petName: firstPet.nombreCanino, breedAge: '—'),
                  error: (_, __) => _buildDogSection(petName: firstPet.nombreCanino, breedAge: '—'),
                );
              },
              loading: () => _buildDogSection(petName: '—', breedAge: '—'),
              error: (_, __) => _buildDogSection(petName: '—', breedAge: '—'),
            ),
            const SizedBox(height: 28),
            // INFORMACIÓN DEL DUEÑO
            const Text(
              'INFORMACIÓN DEL DUEÑO',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 10),
            ownersAsync.when(
              data: (owners) {
                Owner? owner;
                try {
                  owner = owners.firstWhere((o) => o.id == widget.walk.propietarioId);
                } catch (_) {}
                final petName = walkPetsAsync.valueOrNull?.isNotEmpty == true
                    ? walkPetsAsync.valueOrNull!.first.nombreCanino
                    : '—';
                return _buildOwnerCard(
                  ownerName: owner?.nombre ?? '—',
                  nombreMascota: petName,
                  telefono: owner?.telefono ?? '—',
                );
              },
              loading: () => _buildOwnerCard(ownerName: '—', nombreMascota: '—', telefono: '—'),
              error: (_, __) => _buildOwnerCard(ownerName: '—', nombreMascota: '—', telefono: '—'),
            ),
            const SizedBox(height: 24),
            // DETALLES DEL PASEO
            const Text(
              'DETALLES DEL PASEO',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 10),
            _buildDetailRow(
              icon: Icons.access_time,
              label: 'Horario Programado',
              value: '${_formatHora(widget.walk.horaInicio)} (${widget.walk.duracionMinutos ?? 60} min)',
            ),
            const SizedBox(height: 10),
            _buildDetailRow(
              icon: Icons.location_on,
              label: 'Lugar de Recojo',
              value: widget.walk.direccionRecogida ?? '—',
            ),
            const SizedBox(height: 10),
            _buildNotasEspecialesRow(walkPetsAsync, petsAsync),
            const SizedBox(height: 32),
            // Botones
            Row(
              children: [
                Expanded(
                  child: Material(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RescheduleWalkPage(
                              walk: widget.walk,
                              paseadorId: widget.paseadorId,
                            ),
                          ),
                        ).then((_) => setState(() {}));
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFC8E6E3), width: 2.0),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.calendar_today, size: 18, color: AppColors.button),
                            const SizedBox(width: 8),
                            Text(
                              'REPROGRAMAR',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.button,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Material(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: _handleCancelWalk,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.shade200, width: 2.0),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.close, size: 18, color: AppColors.error),
                            const SizedBox(width: 8),
                            Text(
                              'CANCELAR',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.error,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('En construcción'),
                      backgroundColor: AppColors.button,
                    ),
                  );
                },
                icon: const Icon(Icons.play_arrow, size: 20, color: Colors.white),
                label: const Text(
                  'INICIAR PASEO',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.button,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Fila "Notas Especiales"
  Widget _buildNotasEspecialesRow(
    AsyncValue<List<WalkPet>> walkPetsAsync,
    AsyncValue<List<Pet>> petsAsync,
  ) {
    return walkPetsAsync.when(
      data: (walkPets) {
        if (walkPets.isEmpty) {
          return _buildDetailRow(
            icon: Icons.note_alt_outlined,
            label: 'Notas Especiales',
            value: '—',
            isNote: true,
          );
        }
        final firstPet = walkPets.first;
        return petsAsync.when(
          data: (pets) {
            Pet? pet;
            try {
              pet = pets.firstWhere((p) => p.id == firstPet.caninoId);
            } catch (_) {
              pet = null;
            }
            final value = pet?.observaciones ?? '—';
            return _buildDetailRow(
              icon: Icons.note_alt_outlined,
              label: 'Notas Especiales',
              value: value,
              isNote: true,
            );
          },
          loading: () => _buildDetailRow(
            icon: Icons.note_alt_outlined,
            label: 'Notas Especiales',
            value: '—',
            isNote: true,
          ),
          error: (_, __) => _buildDetailRow(
            icon: Icons.note_alt_outlined,
            label: 'Notas Especiales',
            value: '—',
            isNote: true,
          ),
        );
      },
      loading: () => _buildDetailRow(
        icon: Icons.note_alt_outlined,
        label: 'Notas Especiales',
        value: '—',
        isNote: true,
      ),
      error: (_, __) => _buildDetailRow(
        icon: Icons.note_alt_outlined,
        label: 'Notas Especiales',
        value: '—',
        isNote: true,
      ),
    );
  }

  /// Bloque de la sección perro: imagen, nombre y texto raza/edad (dato de caninos).
  Widget _buildDogSection({required String petName, required String breedAge}) {
    return Center(
      child: Column(
        children: [
          Image.asset(
            'images/dog.png',
            width: 70,
            height: 70,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Icon(Icons.pets, size: 48, color: AppColors.button),
          ),
          const SizedBox(height: 14),
          Text(
            petName,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            breedAge,
            style: const TextStyle(
              fontSize: 18,
              color: AppColors.button,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOwnerCard({
    required String ownerName,
    required String nombreMascota,
    required String telefono,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F9F8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: const Color(0xFFF5F0E6),
            child: ClipOval(
              child: Image.asset(
                'images/dueno.png',
                width: 56,
                height: 56,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Icon(Icons.person, size: 32, color: AppColors.button),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ownerName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Responsable de $nombreMascota',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Celular',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                telefono,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.button,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    bool isNote = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.iconBackgroundLight,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Icon(icon, size: 20, color: AppColors.button),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                    fontStyle: isNote && value != '—' ? FontStyle.italic : FontStyle.normal,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
