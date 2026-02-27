import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paseowof/core/widgets/app_input.dart';
import 'package:paseowof/core/widgets/app_button.dart';
import 'package:paseowof/core/utils/validators.dart';
import 'package:paseowof/core/constants/app_colors.dart';
import 'package:paseowof/features/owners_pets/presentation/controllers/owner_form_controller.dart';
import 'package:paseowof/features/owners_pets/presentation/controllers/owner_form_text_controllers.dart';
import 'package:paseowof/features/owners_pets/presentation/controllers/owner_controller.dart';
import 'package:paseowof/features/auth/presentation/providers/auth_providers.dart';

class RegisterOwnerPage extends ConsumerWidget {
  const RegisterOwnerPage({super.key});

  Future<void> _handleRegister(BuildContext context, WidgetRef ref) async {
    final formKey = ref.read(ownerFormKeyProvider);
    final nombreController = ref.read(ownerNombreControllerProvider);
    final ciController = ref.read(ownerCiControllerProvider);
    final telefonoController = ref.read(ownerTelefonoControllerProvider);
    final direccionController = ref.read(ownerDireccionControllerProvider);
    final emailController = ref.read(ownerEmailControllerProvider);

    // Obtener el paseador actual
    final authState = ref.read(authControllerProvider);
    final user = authState.value;
    if (user == null) {
      return;
    }

    if (!formKey.currentState!.validate()) {
      return;
    }

    if (!context.mounted) {
      return;
    }

    final formController = ref.read(ownerFormControllerProvider.notifier);
    formController.setMessage('Registrando propietario...', Colors.blue.shade700);
    formController.setLoading(true);

    try {
      // Agregar timeout para evitar esperas indefinidas
      await ref.read(ownerControllerProvider.notifier).registerOwner(
            paseadorId: user.uid,
            nombre: nombreController.text.trim(),
            ci: '${ciController.text.trim()} LP',
            telefono: telefonoController.text.trim().isEmpty
                ? null
                : telefonoController.text.trim(),
            direccion: direccionController.text.trim().isEmpty
                ? null
                : direccionController.text.trim(),
            email: emailController.text.trim().isEmpty
                ? null
                : emailController.text.trim(),
          ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          // Si hay timeout, asumimos que está offline pero los datos se guardaron localmente
          throw TimeoutException('Sin conexión a internet. Los datos se guardaron localmente y se sincronizarán cuando haya conexión.');
        },
      );

      formController.setMessage('¡Propietario registrado exitosamente!', AppColors.button);
      formController.setLoading(false);

      // Esperar un momento para mostrar el mensaje de éxito
      await Future.delayed(const Duration(milliseconds: 1500));

      if (context.mounted) {
        Navigator.pop(context);
      }
    } on TimeoutException {
      // Manejar timeout - los datos se guardaron localmente
      formController.setMessage('Propietario guardado localmente. Se sincronizará cuando haya conexión.', AppColors.warning);
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
    final formState = ref.watch(ownerFormControllerProvider);
    final formKey = ref.watch(ownerFormKeyProvider);
    final nombreController = ref.watch(ownerNombreControllerProvider);
    final ciController = ref.watch(ownerCiControllerProvider);
    final telefonoController = ref.watch(ownerTelefonoControllerProvider);
    final direccionController = ref.watch(ownerDireccionControllerProvider);
    final emailController = ref.watch(ownerEmailControllerProvider);
    final ownerState = ref.watch(ownerControllerProvider);
    final isLoading = formState.isLoading || ownerState.isLoading;

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
                    'Registro de Propietario',
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
                      AppInput(
                        icon: Icons.person_outline,
                        label: 'Nombre Completo',
                        controller: nombreController,
                        validator: (value) => Validators.required(value, fieldName: 'El nombre'),
                      ),
                      const SizedBox(height: 12),
                      AppInput(
                        icon: Icons.badge_outlined,
                        label: 'CI (Carnet de Identidad)',
                        controller: ciController,
                        keyboardType: TextInputType.number,
                        validator: Validators.ciNumber,
                      ),
                      const SizedBox(height: 12),
                      AppInput(
                        icon: Icons.phone_outlined,
                        label: 'Teléfono (Opcional)',
                        controller: telefonoController,
                        keyboardType: TextInputType.phone,
                        validator: Validators.phone,
                      ),
                      const SizedBox(height: 12),
                      AppInput(
                        icon: Icons.location_on_outlined,
                        label: 'Dirección (Opcional)',
                        controller: direccionController,
                        keyboardType: TextInputType.streetAddress,
                      ),
                      const SizedBox(height: 12),
                      AppInput(
                        icon: Icons.email_outlined,
                        label: 'Correo Electrónico (Opcional)',
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value != null && value.isNotEmpty) {
                            return Validators.email(value);
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Botón de Registro
                AppButton(
                  text: 'REGISTRAR PROPIETARIO',
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
                      Icons.person_add,
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
}

