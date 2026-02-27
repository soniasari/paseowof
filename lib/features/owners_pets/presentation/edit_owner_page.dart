import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paseowof/core/widgets/app_input.dart';
import 'package:paseowof/core/widgets/app_button.dart';
import 'package:paseowof/core/utils/validators.dart';
import 'package:paseowof/core/constants/app_colors.dart';
import 'package:paseowof/features/owners_pets/domain/entities/owner.dart';
import 'package:paseowof/features/owners_pets/presentation/controllers/owner_form_controller.dart';
import 'package:paseowof/features/owners_pets/presentation/controllers/owner_form_text_controllers.dart';
import 'package:paseowof/features/owners_pets/presentation/controllers/owner_controller.dart';
import 'package:paseowof/features/auth/presentation/providers/auth_providers.dart';

class EditOwnerPage extends ConsumerStatefulWidget {
  final Owner owner;

  const EditOwnerPage({
    super.key,
    required this.owner,
  });

  @override
  ConsumerState<EditOwnerPage> createState() => _EditOwnerPageState();
}

class _EditOwnerPageState extends ConsumerState<EditOwnerPage> {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    // Inicializar los campos con los datos del propietario después del primer frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.microtask(() {
        if (mounted) {
          _initializeFields();
        }
      });
    });
  }

  void _initializeFields() {
    if (_initialized) return;
    
    final nombreController = ref.read(ownerNombreControllerProvider);
    final ciController = ref.read(ownerCiControllerProvider);
    final telefonoController = ref.read(ownerTelefonoControllerProvider);
    final direccionController = ref.read(ownerDireccionControllerProvider);
    final emailController = ref.read(ownerEmailControllerProvider);

    nombreController.text = widget.owner.nombre;
    // Omitir " LP" del CI para mostrarlo en el campo
    ciController.text = widget.owner.ci.replaceAll(' LP', '');
    telefonoController.text = widget.owner.telefono ?? '';
    direccionController.text = widget.owner.direccion ?? '';
    emailController.text = widget.owner.email ?? '';

    _initialized = true;
  }

  Future<void> _handleUpdate(BuildContext context, WidgetRef ref) async {
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
    formController.setMessage('Actualizando propietario...', Colors.blue.shade700);
    formController.setLoading(true);

    try {
      await ref.read(ownerControllerProvider.notifier).updateOwner(
            paseadorId: user.uid,
            ownerId: widget.owner.id,
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
          );

      formController.setMessage('¡Datos modificados exitosamente!', AppColors.button);
      formController.setLoading(false);

      // Esperar un momento para mostrar el mensaje de éxito
      await Future.delayed(const Duration(milliseconds: 1500));

      if (context.mounted) {
        // Mostrar snackbar adicional para confirmar la modificación
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Los datos del propietario han sido modificados correctamente'),
            backgroundColor: AppColors.button,
            duration: Duration(seconds: 2),
          ),
        );
        
        Navigator.pop(context);
      }
    } catch (e) {
      formController.setMessage('Error: ${e.toString()}', Colors.red.shade700);
      formController.setLoading(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(ownerFormControllerProvider);
    final formKey = ref.watch(ownerFormKeyProvider);
    final nombreController = ref.watch(ownerNombreControllerProvider);
    final ciController = ref.watch(ownerCiControllerProvider);
    final telefonoController = ref.watch(ownerTelefonoControllerProvider);
    final direccionController = ref.watch(ownerDireccionControllerProvider);
    final emailController = ref.watch(ownerEmailControllerProvider);
    final ownerState = ref.watch(ownerControllerProvider);
    final isLoading = formState.isLoading || ownerState.isLoading;

    // Inicializar campos si no se ha hecho (usando Future para evitar modificar durante build)
    if (!_initialized) {
      Future.microtask(() {
        if (mounted) {
          _initializeFields();
        }
      });
    }

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
                    'Modificar Propietario',
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

                // Formulario de Edición
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
                const SizedBox(height: 24),

                // Botón de Actualización
                AppButton(
                  text: 'ACTUALIZAR PROPIETARIO',
                  onPressed: isLoading ? null : () => _handleUpdate(context, ref),
                  isLoading: isLoading,
                  icon: const Icon(Icons.save, size: 20, color: AppColors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

