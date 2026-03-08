import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paseowof/core/constants/app_colors.dart';
import 'package:paseowof/features/owners_pets/presentation/providers/owner_pet_providers.dart';
import 'package:paseowof/features/auth/presentation/providers/auth_providers.dart';
import 'package:paseowof/features/owners_pets/domain/entities/pet.dart';
import 'package:paseowof/features/owners_pets/presentation/edit_pet_page.dart';
import 'package:paseowof/features/owners_pets/presentation/register_pet_page.dart';

class PetsListPage extends ConsumerWidget {
  const PetsListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final user = authState.value;
    final paseadorId = user?.uid ?? '';

    final petsAsync = ref.watch(petsListProvider(paseadorId));

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: const Text(
          'Registro de Canes',
          style: TextStyle(
            color: AppColors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: AppColors.button,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: petsAsync.when(
        data: (pets) {
          return Column(
            children: [
              // Header con título y botón
              Container(
                padding: const EdgeInsets.all(16),
                color: AppColors.white,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Registro de Canes (${pets.length})',
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
                            builder: (context) => const RegisterPetPage(),
                          ),
                        ).then((_) {
                          // Refrescar la lista cuando se regrese del registro
                          final authState = ref.read(authControllerProvider);
                          final user = authState.value;
                          if (user != null) {
                            ref.invalidate(petsListProvider(user.uid));
                          }
                        });
                      },
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Nuevo Can'),
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
              // Lista de caninos
              if (pets.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.pets,
                          size: 64,
                          color: AppColors.textGrey.withOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No hay caninos registrados',
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
                    itemCount: pets.length,
                    itemBuilder: (context, index) {
                      final pet = pets[index];
                      return _buildPetCard(context, ref, pet);
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
                'Error al cargar caninos',
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

  Widget _buildPetCard(BuildContext context, WidgetRef ref, Pet pet) {
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
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.pets,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pet.nombre,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    if (pet.raza != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        pet.raza!,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textGrey,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (pet.edad != null || pet.tamano != null || pet.peso != null) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                if (pet.edad != null)
                  _buildInfoChip(
                    icon: Icons.cake,
                    label: '${pet.edad} años',
                  ),
                if (pet.tamano != null)
                  _buildInfoChip(
                    icon: Icons.straighten,
                    label: pet.tamano![0].toUpperCase() + pet.tamano!.substring(1),
                  ),
                if (pet.peso != null)
                  _buildInfoChip(
                    icon: Icons.monitor_weight,
                    label: '${pet.peso} kg',
                  ),
              ],
            ),
          ],
          // Mostrar observaciones si existen
          if (pet.observaciones != null && pet.observaciones!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.orange,
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.orange,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    pet.observaciones!,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textDark,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  onPressed: () => _handleEditPet(context, ref, pet),
                  icon: Icon(
                    Icons.edit_outlined,
                    color: const Color(0xFF6a4c8d),
                    size: 20,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: () => _handleDeletePet(context, ref, pet),
                  icon: Icon(
                    Icons.delete_outline,
                    color: AppColors.error,
                    size: 20,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _handleEditPet(BuildContext context, WidgetRef ref, Pet pet) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditPetPage(pet: pet),
      ),
    ).then((_) {
      // Refrescar la lista cuando se regrese de la edición
      final authState = ref.read(authControllerProvider);
      final user = authState.value;
      if (user != null) {
        ref.invalidate(petsListProvider(user.uid));
      }
    });
  }

  Future<void> _handleDeletePet(BuildContext context, WidgetRef ref, Pet pet) async {
    final authState = ref.read(authControllerProvider);
    final user = authState.value;
    final paseadorId = user?.uid ?? '';
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar Canino'),
        content: const Text('¿Estás seguro de que deseas eliminar este canino? Esta acción no se puede deshacer.'),
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
      await repository.deletePet(paseadorId, pet.id);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Canino eliminado exitosamente'),
            backgroundColor: AppColors.success,
          ),
        );
        // Refrescar la lista
        ref.invalidate(petsListProvider(paseadorId));
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

  Widget _buildInfoChip({required IconData icon, required String label}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.textGrey),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textGrey,
          ),
        ),
      ],
    );
  }
}

