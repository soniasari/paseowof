import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paseowof/core/constants/app_colors.dart';
import 'package:paseowof/features/owners_pets/presentation/providers/owner_pet_providers.dart';
import 'package:paseowof/features/auth/presentation/providers/auth_providers.dart';
import 'package:paseowof/features/owners_pets/domain/entities/owner.dart';
import 'package:paseowof/features/owners_pets/presentation/edit_owner_page.dart';
import 'package:paseowof/features/owners_pets/presentation/register_owner_page.dart';

class OwnersListPage extends ConsumerWidget {
  const OwnersListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final user = authState.value;
    final paseadorId = user?.uid ?? '';

    final ownersAsync = ref.watch(ownersListProvider(paseadorId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Lista de Propietarios',
          style: TextStyle(
            color: AppColors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: const Color(0xFF0A8F68),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ownersAsync.when(
        data: (owners) {
          return Column(
            children: [
              // Header con título y botón
              Container(
                padding: const EdgeInsets.all(16),
                color: AppColors.background,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Mis Clientes (${owners.length})',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const RegisterOwnerPage(),
                          ),
                        ).then((_) {
                          // Refrescar la lista cuando se regrese del registro
                          final authState = ref.read(authControllerProvider);
                          final user = authState.value;
                          if (user != null) {
                            ref.invalidate(ownersListProvider(user.uid));
                          }
                        });
                      },
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Nuevo Cliente'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Lista de propietarios
              if (owners.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people,
                          size: 64,
                          color: AppColors.textGrey.withOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No hay propietarios registrados',
                          style: TextStyle(
                            fontSize: 18,
                            color: AppColors.textGrey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: owners.length,
                    itemBuilder: (context, index) {
                      final owner = owners[index];
                      return _buildOwnerCard(context, ref, owner, paseadorId);
                    },
                  ),
                ),
            ],
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: AppColors.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Error al cargar propietarios',
                style: TextStyle(
                  fontSize: 18,
                  color: AppColors.error,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textGrey,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOwnerCard(BuildContext context, WidgetRef ref, Owner owner, String paseadorId) {
    final petsAsync = ref.watch(petsListProvider(paseadorId));
    
    // Obtener inicial del nombre para el avatar
    final initial = owner.nombre.isNotEmpty ? owner.nombre[0].toUpperCase() : '?';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.secondary,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar circular con inicial
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    initial,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  owner.nombre,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Email
          if (owner.email != null) ...[
            Row(
              children: [
                Icon(Icons.email, size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    owner.email!,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          // Teléfono y Dirección en la misma línea
          Row(
            children: [
              if (owner.telefono != null) ...[
                Icon(Icons.badge_outlined, size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  owner.telefono!,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(width: 16),
              ],
              if (owner.direccion != null) ...[
                Icon(Icons.home_outlined, size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    owner.direccion!,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textDark,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
          // Canes asociados
          petsAsync.when(
            data: (pets) {
              final ownerPets = pets.where((pet) => pet.propietarioId == owner.id).toList();
              if (ownerPets.isEmpty) {
                return const SizedBox.shrink();
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.pets, size: 16, color: AppColors.primary),
                      const SizedBox(width: 8),
                      const Text(
                        'Canes: ',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textDark,
                        ),
                      ),
                      Expanded(
                        child: Wrap(
                          spacing: 6,
                          children: ownerPets.map((pet) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                pet.nombre,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          // Botones de acción (siempre visibles)
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                onPressed: () => _handleEditOwner(context, ref, owner),
                icon: Icon(
                  Icons.edit_outlined,
                  color: const Color(0xFF6a4c8d),
                  size: 20,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Editar propietario',
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => _handleDeleteOwner(context, ref, paseadorId, owner.id),
                icon: Icon(
                  Icons.delete_outline,
                  color: AppColors.error,
                  size: 20,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Eliminar propietario',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handleEditOwner(BuildContext context, WidgetRef ref, Owner owner) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditOwnerPage(owner: owner),
      ),
    ).then((_) {
      // Refrescar la lista cuando se regrese de la edición
      final authState = ref.read(authControllerProvider);
      final user = authState.value;
      if (user != null) {
        ref.invalidate(ownersListProvider(user.uid));
      }
    });
  }

  Future<void> _handleDeleteOwner(BuildContext context, WidgetRef ref, String paseadorId, String ownerId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar Propietario'),
        content: const Text('¿Estás seguro de que deseas eliminar este propietario? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm != true) {
      return;
    }

    try {
      final repository = ref.read(ownerPetRepositoryProvider);
      await repository.deleteOwner(paseadorId, ownerId);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Propietario eliminado exitosamente'),
            backgroundColor: AppColors.success,
          ),
        );
        // Refrescar la lista
        ref.invalidate(ownersListProvider(paseadorId));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al eliminar: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

}

