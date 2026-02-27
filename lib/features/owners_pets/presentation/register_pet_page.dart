import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paseowof/core/widgets/app_input.dart';
import 'package:paseowof/core/widgets/app_button.dart';
import 'package:paseowof/core/utils/validators.dart';
import 'package:paseowof/core/constants/app_colors.dart';
import 'package:paseowof/features/owners_pets/domain/entities/owner.dart';
import 'package:paseowof/features/owners_pets/presentation/controllers/pet_form_controller.dart';
import 'package:paseowof/features/owners_pets/presentation/controllers/pet_form_text_controllers.dart';
import 'package:paseowof/features/owners_pets/presentation/controllers/pet_controller.dart';
import 'package:paseowof/features/owners_pets/presentation/providers/owner_pet_providers.dart';
import 'package:paseowof/features/auth/presentation/providers/auth_providers.dart';

class RegisterPetPage extends ConsumerWidget {
  const RegisterPetPage({super.key});

  Future<void> _handleRegister(BuildContext context, WidgetRef ref) async {
    final formKey = ref.read(petFormKeyProvider);
    final nombreController = ref.read(petNombreControllerProvider);
    final razaController = ref.read(petRazaControllerProvider);
    final edadController = ref.read(petEdadControllerProvider);
    final pesoController = ref.read(petPesoControllerProvider);
    final colorController = ref.read(petColorControllerProvider);
    final observacionesController = ref.read(petObservacionesControllerProvider);

    // Obtener el paseador actual
    final authState = ref.read(authControllerProvider);
    final user = authState.value;
    if (user == null) {
      return;
    }

    // Obtener el propietario seleccionado del estado
    final selectedOwnerId = ref.read(selectedOwnerIdProvider);
    if (selectedOwnerId == null) {
      final formController = ref.read(petFormControllerProvider.notifier);
      formController.setMessage('Debes seleccionar un propietario', Colors.red.shade700);
      return;
    }

    if (!formKey.currentState!.validate()) {
      return;
    }

    if (!context.mounted) {
      return;
    }

    final formController = ref.read(petFormControllerProvider.notifier);
    formController.setMessage('Registrando canino...', Colors.blue.shade700);
    formController.setLoading(true);

    try {
      // Parsear edad y peso
      int? edad;
      if (edadController.text.trim().isNotEmpty) {
        edad = int.tryParse(edadController.text.trim());
      }

      double? peso;
      if (pesoController.text.trim().isNotEmpty) {
        peso = double.tryParse(pesoController.text.trim());
      }

      await ref.read(petControllerProvider.notifier).registerPet(
            paseadorId: user.uid,
            propietarioId: selectedOwnerId,
            nombre: nombreController.text.trim(),
            raza: razaController.text.trim().isEmpty ? null : razaController.text.trim(),
            edad: edad,
            tamano: ref.read(selectedTamanoProvider),
            nivelEnergia: ref.read(selectedNivelEnergiaProvider),
            observaciones: observacionesController.text.trim().isEmpty
                ? null
                : observacionesController.text.trim(),
            peso: peso,
            color: colorController.text.trim().isEmpty ? null : colorController.text.trim(),
            foto: null, // Por ahora sin foto
          ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          // Si hay timeout, asumimos que está offline pero los datos se guardaron localmente
          throw TimeoutException('Sin conexión a internet. Los datos se guardaron localmente y se sincronizarán cuando haya conexión.');
        },
      );

      formController.setMessage('¡Canino registrado exitosamente!', AppColors.button);
      formController.setLoading(false);

      // Esperar un momento para mostrar el mensaje de éxito
      await Future.delayed(const Duration(milliseconds: 1500));

      if (context.mounted) {
        Navigator.pop(context);
      }
    } on TimeoutException {
      // Manejar timeout - los datos se guardaron localmente
      formController.setMessage('Canino guardado localmente. Se sincronizará cuando haya conexión.', AppColors.warning);
      formController.setLoading(false);
      
      // Esperar un momento y cerrar
      await Future.delayed(const Duration(milliseconds: 2000));
      if (context.mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      // Verificar si es un error de red (offline)
      final errorMessage = e.toString().toLowerCase();
      if (errorMessage.contains('network') || 
          errorMessage.contains('unavailable') ||
          errorMessage.contains('deadline') ||
          errorMessage.contains('connection')) {
        formController.setMessage('Sin conexión. Los datos se guardaron localmente y se sincronizarán automáticamente cuando haya internet.', AppColors.warning);
        formController.setLoading(false);
        
        // Esperar un momento y cerrar
        await Future.delayed(const Duration(milliseconds: 2000));
        if (context.mounted) {
          Navigator.pop(context);
        }
      } else {
        formController.setMessage('Error: ${e.toString()}', Colors.red.shade700);
        formController.setLoading(false);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final formState = ref.watch(petFormControllerProvider);
    final formKey = ref.watch(petFormKeyProvider);
    final nombreController = ref.watch(petNombreControllerProvider);
    final razaController = ref.watch(petRazaControllerProvider);
    final edadController = ref.watch(petEdadControllerProvider);
    final pesoController = ref.watch(petPesoControllerProvider);
    final colorController = ref.watch(petColorControllerProvider);
    final observacionesController = ref.watch(petObservacionesControllerProvider);

    // Obtener el paseador actual
    final user = authState.value;
    final paseadorId = user?.uid ?? '';

    // Obtener lista de propietarios
    final ownersAsync = ref.watch(ownersListProvider(paseadorId));
    final petState = ref.watch(petControllerProvider);
    final isLoading = formState.isLoading || petState.isLoading;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text.rich(
          TextSpan(
            text: 'Paseo',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w300,
              color: AppColors.white,
            ),
            children: <TextSpan>[
              TextSpan(
                text: 'Woow',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.white,
                ),
              ),
            ],
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
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 16.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                Image.asset(
                  'images/dog.png',
                  width: 40,
                  height: 40,
                ),
                const SizedBox(height: 8),
                const Center(
                  child: Text(
                    'Registro de Can',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Mensaje de Estado
                if (formState.message.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: formState.messageColor.withOpacity(0.1),
                      border: Border(
                        left: BorderSide(color: formState.messageColor, width: 4),
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      formState.message,
                      style: TextStyle(
                        color: formState.messageColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                // Formulario de Registro
                Form(
                  key: formKey,
                  child: Column(
                    children: [
                      // Selector de Propietario
                      ownersAsync.when(
                        data: (owners) {
                          if (owners.isEmpty) {
                            return Container(
                              padding: const EdgeInsets.all(16),
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.orange.shade200),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.info_outline, color: Colors.orange.shade700, size: 20),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'No hay propietarios registrados. Debes registrar un propietario primero.',
                                      style: TextStyle(
                                        color: Colors.orange.shade700,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }
                          return Column(
                            children: [
                              _buildOwnerDropdown(context, ref, owners),
                              const SizedBox(height: 12),
                              _buildOwnerCiDisplay(context, ref, owners),
                            ],
                          );
                        },
                        loading: () => const Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: CircularProgressIndicator(),
                        ),
                        error: (error, stack) => Container(
                          padding: const EdgeInsets.all(16),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Text(
                            'Error al cargar propietarios: ${error.toString()}',
                            style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                          ),
                        ),
                      ),

                      AppInput(
                        icon: Icons.pets,
                        label: 'Nombre del Canino',
                        controller: nombreController,
                        validator: (value) => Validators.required(value, fieldName: 'El nombre'),
                      ),
                      const SizedBox(height: 12),
                      AppInput(
                        icon: Icons.category,
                        label: 'Raza (Opcional)',
                        controller: razaController,
                      ),
                      const SizedBox(height: 12),
                      AppInput(
                        icon: Icons.cake,
                        label: 'Edad en años (Opcional)',
                        controller: edadController,
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value != null && value.isNotEmpty) {
                            final edad = int.tryParse(value);
                            if (edad == null || edad < 0 || edad > 30) {
                              return 'Ingresa una edad válida (0-30 años)';
                            }
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildTamanoDropdown(context, ref),
                      const SizedBox(height: 12),
                      _buildNivelEnergiaDropdown(context, ref),
                      const SizedBox(height: 12),
                      AppInput(
                        icon: Icons.monitor_weight,
                        label: 'Peso en kg (Opcional)',
                        controller: pesoController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (value) {
                          if (value != null && value.isNotEmpty) {
                            final peso = double.tryParse(value);
                            if (peso == null || peso < 0 || peso > 100) {
                              return 'Ingresa un peso válido (0-100 kg)';
                            }
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      AppInput(
                        icon: Icons.palette,
                        label: 'Color (Opcional)',
                        controller: colorController,
                      ),
                      const SizedBox(height: 12),
                      AppInput(
                        icon: Icons.note,
                        label: 'Observaciones (Opcional)',
                        controller: observacionesController,
                        keyboardType: TextInputType.multiline,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Botón de Registro
                AppButton(
                  text: 'REGISTRAR CANINO',
                  onPressed: isLoading ? null : () => _handleRegister(context, ref),
                  isLoading: isLoading,
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
                      Icons.pets,
                      size: 12,
                      color: AppColors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOwnerDropdown(BuildContext context, WidgetRef ref, List<Owner> owners) {
    final selectedOwnerId = ref.watch(selectedOwnerIdProvider);
    Owner? selectedOwner;
    if (selectedOwnerId != null) {
      try {
        selectedOwner = owners.firstWhere((owner) => owner.id == selectedOwnerId);
      } catch (_) {
        selectedOwner = null;
      }
    }
    if (selectedOwner == null && owners.isNotEmpty) {
      selectedOwner = owners.first;
      // Usar postFrameCallback para evitar modificar el provider durante el build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (ref.read(selectedOwnerIdProvider) == null) {
          ref.read(selectedOwnerIdProvider.notifier).state = owners.first.id;
        }
      });
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey[400]!, width: 1),
        ),
      ),
      child: DropdownButtonFormField<Owner>(
        value: selectedOwnerId != null ? selectedOwner : null,
        decoration: InputDecoration(
          labelText: 'Propietario *',
          labelStyle: TextStyle(
            color: Colors.grey[500],
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: Icon(Icons.person, color: Colors.grey[400], size: 20),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
        ),
        items: owners.map((owner) {
          return DropdownMenuItem<Owner>(
            value: owner,
            child: Text(
              owner.nombre,
              style: const TextStyle(
                color: AppColors.textDark,
                fontSize: 16,
              ),
            ),
          );
        }).toList(),
        onChanged: (Owner? owner) {
          if (owner != null) {
            ref.read(selectedOwnerIdProvider.notifier).state = owner.id;
          }
        },
        validator: (value) {
          if (value == null) {
            return 'Debes seleccionar un propietario';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildTamanoDropdown(BuildContext context, WidgetRef ref) {
    final selectedTamano = ref.watch(selectedTamanoProvider);
    final tamanos = ['pequeño', 'mediano', 'grande'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey[400]!, width: 1),
        ),
      ),
      child: DropdownButtonFormField<String>(
        value: selectedTamano,
        decoration: InputDecoration(
          labelText: 'Tamaño (Opcional)',
          labelStyle: TextStyle(
            color: Colors.grey[500],
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: Icon(Icons.straighten, color: Colors.grey[400], size: 20),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
        ),
        items: tamanos.map((tamano) {
          return DropdownMenuItem<String>(
            value: tamano,
            child: Text(
              tamano[0].toUpperCase() + tamano.substring(1),
              style: const TextStyle(
                color: AppColors.textDark,
                fontSize: 16,
              ),
            ),
          );
        }).toList(),
        onChanged: (value) {
          ref.read(selectedTamanoProvider.notifier).state = value;
        },
      ),
    );
  }

  Widget _buildNivelEnergiaDropdown(BuildContext context, WidgetRef ref) {
    final selectedNivel = ref.watch(selectedNivelEnergiaProvider);
    final niveles = ['bajo', 'medio', 'alto'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey[400]!, width: 1),
        ),
      ),
      child: DropdownButtonFormField<String>(
        value: selectedNivel,
        decoration: InputDecoration(
          labelText: 'Nivel de Energía (Opcional)',
          labelStyle: TextStyle(
            color: Colors.grey[500],
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: Icon(Icons.bolt, color: Colors.grey[400], size: 20),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
        ),
        items: niveles.map((nivel) {
          return DropdownMenuItem<String>(
            value: nivel,
            child: Text(
              nivel[0].toUpperCase() + nivel.substring(1),
              style: const TextStyle(
                color: AppColors.textDark,
                fontSize: 16,
              ),
            ),
          );
        }).toList(),
        onChanged: (value) {
          ref.read(selectedNivelEnergiaProvider.notifier).state = value;
        },
      ),
    );
  }

  Widget _buildOwnerCiDisplay(BuildContext context, WidgetRef ref, List<Owner> owners) {
    final selectedOwnerId = ref.watch(selectedOwnerIdProvider);
    
    if (selectedOwnerId == null) {
      return const SizedBox.shrink();
    }

    Owner? selectedOwner;
    try {
      selectedOwner = owners.firstWhere((owner) => owner.id == selectedOwnerId);
    } catch (_) {
      return const SizedBox.shrink();
    }

    // Obtener solo los números del CI (omitir " LP")
    final ciNumber = selectedOwner.ci.replaceAll(' LP', '').trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey[400]!, width: 1),
        ),
      ),
      child: TextFormField(
        key: ValueKey(selectedOwnerId), // Forzar reconstrucción cuando cambie el propietario
        initialValue: ciNumber,
        enabled: false,
        decoration: InputDecoration(
          labelText: 'CI del Propietario (Solo lectura)',
          labelStyle: TextStyle(
            color: Colors.grey[500],
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: Icon(Icons.badge_outlined, color: Colors.grey[400], size: 20),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
        ),
        style: const TextStyle(
          color: AppColors.textDark,
          fontSize: 16,
        ),
      ),
    );
  }
}


