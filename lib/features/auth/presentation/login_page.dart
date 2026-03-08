import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/widgets/app_input.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/constants/app_colors.dart';
import 'providers/auth_providers.dart';
import 'controllers/login_form_text_controllers.dart';
import 'register_page.dart';
import 'reset_password_page.dart';
import '../../home/presentation/home_page.dart';
import '../../home/presentation/providers/home_providers.dart';

class LoginPage extends ConsumerWidget {
  const LoginPage({super.key});

  Future<void> _handleLogin(BuildContext context, WidgetRef ref) async {
    final formKey = ref.read(loginFormKeyProvider);
    final emailController = ref.read(loginEmailControllerProvider);
    final passwordController = ref.read(loginPasswordControllerProvider);

    if (!formKey.currentState!.validate()) {
      return;
    }

    final formController = ref.read(loginFormControllerProvider.notifier);
    formController.setMessage('Verificando credenciales...', Colors.blue.shade700);

    try {
      await ref.read(authControllerProvider.notifier).signInWithEmailAndPassword(
            email: emailController.text.trim(),
            password: passwordController.text,
          );

      formController.setMessage('¡Bienvenido! Redireccionando...', AppColors.button);

      ref.read(homeNavigationControllerProvider.notifier).setIndex(0);

      // Volvemos al inicio y abrimos la pantalla principal
      Future.delayed(const Duration(milliseconds: 500), () {
        if (context.mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomePage()),
          );
        }
      });
    } on FirebaseAuthException catch (e) {
      String message = 'Error al iniciar sesión';
      switch (e.code) {
        case 'user-not-found':
          message = 'No existe una cuenta con este correo electrónico';
          break;
        case 'wrong-password':
          message = 'Contraseña incorrecta';
          break;
        case 'invalid-email':
          message = 'Correo electrónico inválido';
          break;
        case 'user-disabled':
          message = 'Esta cuenta ha sido deshabilitada';
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
    final formState = ref.watch(loginFormControllerProvider);
    final formKey = ref.watch(loginFormKeyProvider);
    final emailController = ref.watch(loginEmailControllerProvider);
    final passwordController = ref.watch(loginPasswordControllerProvider);
    final isLoading = authState.isLoading || formState.isLoading;
    
    // Si cerró sesión, limpiamos el mensaje para no mostrar cosas de la sesión anterior
    authState.whenData((user) {
      if (user == null && formState.message.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(loginFormControllerProvider.notifier).clearMessage();
        });
      }
    });

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo y título
                Image.asset(
                  'images/dog.png',
                  width: 64,
                  height: 64,
                ),
                const SizedBox(height: 12),
                const Center(
                  child: Text.rich(
                    TextSpan(
                      text: 'Paseo',
                      style: TextStyle(
                        fontSize: 48,
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
                const SizedBox(height: 8),
                const Center(
                  child: Text(
                    'Accede a tu cuenta de paseador',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textGrey,
                    ),
                  ),
                ),
                const SizedBox(height: 48),

                // Mensaje (error, éxito, etc.)
                if (formState.message.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 32),
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

                // Formulario
                Form(
                  key: formKey,
                  child: Column(
                    children: [
                      AppInput(
                        icon: Icons.email_outlined,
                        label: 'Correo Electrónico',
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        validator: Validators.email,
                      ),
                      const SizedBox(height: 20),
                      AppInput(
                        icon: Icons.lock_outline,
                        label: 'Contraseña',
                        controller: passwordController,
                        isPassword: true,
                        validator: Validators.password,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),
                // Olvidé contraseña
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ResetPasswordPage(),
                        ),
                      );
                    },
                    child: Text(
                      '¿Olvidaste tu Contraseña?',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.button,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Botón entrar
                AppButton(
                  text: 'INICIAR SESIÓN',
                  onPressed: isLoading ? null : () async => await _handleLogin(context, ref),
                  isLoading: isLoading,
                  icon: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.white, width: 1.5),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: const Icon(
                      Icons.arrow_forward,
                      size: 14,
                      color: AppColors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 48),

                // Separador y link a registro
                Row(
                  children: [
                    Expanded(
                      child: Divider(
                        color: Colors.grey.shade300,
                        thickness: 1,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text(
                        '¿Aún no tienes cuenta?',
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Divider(
                        color: Colors.grey.shade300,
                        thickness: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Botón registrarse
                TextButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const RegisterPage(),
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.person_add_outlined,
                    color: AppColors.button,
                    size: 20,
                  ),
                  label: const Text(
                    'Registrarme',
                    style: TextStyle(
                      color: AppColors.button,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
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
