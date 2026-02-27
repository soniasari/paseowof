import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/widgets/app_input.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/constants/app_colors.dart';
import 'package:paseowof/features/auth/domain/entities/walker.dart';
import 'providers/auth_providers.dart';
import 'controllers/register_form_text_controllers.dart';
import 'login_page.dart';

class RegisterPage extends ConsumerWidget {
  const RegisterPage({super.key});

  String? _validateConfirmPassword(String? value, TextEditingController passwordController) {
    if (value == null || value.isEmpty) {
      return 'Confirma tu contraseña';
    }
    if (value != passwordController.text) {
      return 'Las contraseñas no coinciden';
    }
    return null;
  }

  Future<void> _handleRegister(BuildContext context, WidgetRef ref) async {
    final formKey = ref.read(registerFormKeyProvider);
    final nombreController = ref.read(registerNombreControllerProvider);
    final ciController = ref.read(registerCiControllerProvider);
    final emailController = ref.read(registerEmailControllerProvider);
    final telefonoController = ref.read(registerTelefonoControllerProvider);
    final passwordController = ref.read(registerPasswordControllerProvider);

    if (!formKey.currentState!.validate()) {
      return;
    }

    // Verificar que el contexto esté montado
    if (!context.mounted) {
      return;
    }

    final formController = ref.read(registerFormControllerProvider.notifier);
    formController.setMessage('Creando tu cuenta...', Colors.blue.shade700);

    try {
      // Crear objeto Walker
      final walker = Walker(
        id: '', // Se asignará después de crear el usuario
        nombre: nombreController.text.trim(),
        ci: '${ciController.text.trim()} LP',
        email: emailController.text.trim(),
        telefono: telefonoController.text.trim().isEmpty
            ? null
            : telefonoController.text.trim(),
        fechaRegistro: DateTime.now(),
        activo: true,
      );

      await ref.read(authControllerProvider.notifier).registerWithEmailAndPassword(
            email: emailController.text.trim(),
            password: passwordController.text,
            walker: walker,
          );

      formController.setMessage('¡Cuenta creada exitosamente! Redireccionando...', AppColors.button);

      // Esperar un momento para mostrar el mensaje de éxito
      await Future.delayed(const Duration(milliseconds: 1500));
      
      // Verificar que el contexto sigue siendo válido antes de navegar
      if (!context.mounted) {
        return;
      }

      // Navegar al login
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const LoginPage(),
        ),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      String message = 'Error al crear la cuenta';
      switch (e.code) {
        case 'email-already-in-use':
          message = 'Este correo electrónico ya está registrado';
          break;
        case 'invalid-email':
          message = 'Correo electrónico inválido';
          break;
        case 'weak-password':
          message = 'La contraseña es muy débil';
          break;
      }
      formController.setMessage(message, Colors.red.shade700);
    } catch (e) {
      formController.setMessage('Error: ${e.toString()}', Colors.red.shade700);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final formState = ref.watch(registerFormControllerProvider);
    final formKey = ref.watch(registerFormKeyProvider);
    final nombreController = ref.watch(registerNombreControllerProvider);
    final ciController = ref.watch(registerCiControllerProvider);
    final emailController = ref.watch(registerEmailControllerProvider);
    final telefonoController = ref.watch(registerTelefonoControllerProvider);
    final passwordController = ref.watch(registerPasswordControllerProvider);
    final confirmPasswordController = ref.watch(registerConfirmPasswordControllerProvider);
    final isLoading = authState.isLoading || formState.isLoading;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
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
                  // Logo - más pequeño
                  Image.asset(
                    'images/dog.png',
                    width: 40,
                    height: 40,
                  ),
                  const SizedBox(height: 8),
                  const Center(
                    child: Text.rich(
                      TextSpan(
                        text: 'Paseo',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w300,
                          color: AppColors.textDark,
                        ),
                        children: <TextSpan>[
                          TextSpan(
                            text: 'Woow',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.button,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Center(
                    child: Text(
                      'Crea tu cuenta de paseador',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textGrey,
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
                          icon: Icons.email_outlined,
                          label: 'Correo Electrónico',
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          validator: Validators.email,
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
                          icon: Icons.lock_outline,
                          label: 'Contraseña',
                          controller: passwordController,
                          isPassword: true,
                          validator: Validators.password,
                        ),
                        const SizedBox(height: 12),
                        AppInput(
                          icon: Icons.lock_outline,
                          label: 'Confirmar Contraseña',
                          controller: confirmPasswordController,
                          isPassword: true,
                          validator: (value) => _validateConfirmPassword(value, passwordController),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Botón de Registro
                  ElevatedButton.icon(
                    onPressed: isLoading ? null : () => _handleRegister(context, ref),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.button,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 10,
                      shadowColor: AppColors.button.withOpacity(0.4),
                    ),
                    icon: isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 3,
                            ),
                          )
                        : const Icon(Icons.person_add, size: 20),
                    label: Text(
                      isLoading ? 'CREANDO...' : 'REGISTRARME',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Link para volver al login
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        '¿Ya tienes cuenta? ',
                        style: TextStyle(
                          color: AppColors.textGrey,
                          fontSize: 14,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          if (context.mounted) {
                            Navigator.pop(context);
                          }
                        },
                        child: const Text(
                          'Inicia sesión',
                          style: TextStyle(
                            color: AppColors.button,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
  }
}
