import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/widgets/app_input.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/constants/app_colors.dart';
import 'providers/auth_providers.dart';
import 'controllers/reset_password_text_controllers.dart';
import 'controllers/reset_password_form_controller.dart';

class ResetPasswordPage extends ConsumerStatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  ConsumerState<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends ConsumerState<ResetPasswordPage> {
  Future<void> _handleResetPassword() async {
    final formKey = ref.read(resetPasswordFormKeyProvider);
    final emailController = ref.read(resetPasswordEmailControllerProvider);

    if (!formKey.currentState!.validate()) {
      return;
    }

    final formController = ref.read(resetPasswordFormControllerProvider.notifier);
    formController.setMessage('Enviando correo de recuperación...', Colors.blue.shade700);
    formController.setLoading(true);

    try {
      await ref.read(authControllerProvider.notifier).sendPasswordResetEmail(
            email: emailController.text.trim(),
          );

      formController.setMessage('¡Correo enviado exitosamente!', AppColors.success);
      formController.setLoading(false);
      formController.setEmailSent(true);
    } on FirebaseAuthException catch (e) {
      String message = 'Error al enviar el correo';
      switch (e.code) {
        case 'user-not-found':
          message = 'No existe una cuenta con este correo electrónico';
          break;
        case 'invalid-email':
          message = 'Correo electrónico inválido';
          break;
        case 'too-many-requests':
          message = 'Demasiados intentos. Intenta más tarde';
          break;
      }
      formController.setMessage(message, Colors.red.shade700);
      formController.setLoading(false);
    } catch (e) {
      formController.setMessage('Error: ${e.toString()}', Colors.red.shade700);
      formController.setLoading(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(resetPasswordFormControllerProvider);
    final formKey = ref.watch(resetPasswordFormKeyProvider);
    final emailController = ref.watch(resetPasswordEmailControllerProvider);
    final isLoading = formState.isLoading;
    final emailSent = formState.emailSent;

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
                    'Recuperar Contraseña',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Center(
                  child: Text(
                    'Ingresa tu correo electrónico y te enviaremos un enlace para restablecer tu contraseña',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textGrey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 24),

                // Mensaje de Estado
                if (formState.message.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
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

                if (!emailSent) ...[
                  // Formulario
                  Form(
                    key: formKey,
                    child: AppInput(
                      icon: Icons.email_outlined,
                      label: 'Correo Electrónico',
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      validator: Validators.email,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Botón de Enviar
                  AppButton(
                    text: 'ENVIAR CORREO',
                    onPressed: isLoading ? null : _handleResetPassword,
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
                        Icons.email,
                        size: 12,
                        color: AppColors.white,
                      ),
                    ),
                  ),
                ] else ...[
                  // Mensaje de éxito
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.success),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 64,
                          color: AppColors.success,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Correo Enviado',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Revisa tu correo electrónico (${emailController.text.trim()}) y sigue las instrucciones para restablecer tu contraseña.',
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textGrey,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  AppButton(
                    text: 'VOLVER AL INICIO',
                    onPressed: () => Navigator.pop(context),
                    backgroundColor: AppColors.button,
                    height: 48,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
