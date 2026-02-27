import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paseowof/core/widgets/app_input.dart';
import 'package:paseowof/core/widgets/app_button.dart';
import 'package:paseowof/core/utils/validators.dart';
import 'package:paseowof/core/constants/app_colors.dart';
import 'package:paseowof/features/owners_pets/domain/entities/pet.dart';
import 'package:paseowof/features/owners_pets/domain/entities/owner.dart';
import 'package:paseowof/features/owners_pets/presentation/controllers/pet_form_controller.dart';
import 'package:paseowof/features/owners_pets/presentation/controllers/pet_form_text_controllers.dart';
import 'package:paseowof/features/owners_pets/presentation/controllers/pet_controller.dart';
import 'package:paseowof/features/owners_pets/presentation/providers/owner_pet_providers.dart';
import 'package:paseowof/features/auth/presentation/providers/auth_providers.dart';

class EditPetPage extends ConsumerStatefulWidget {
  final Pet pet;

  const EditPetPage({
    super.key,
    required this.pet,
  });

  @override
  ConsumerState<EditPetPage> createState() => _EditPetPageState();
}

class _EditPetPageState extends ConsumerState<EditPetPage> {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    // Inicializar los campos con los datos del canino después del primer frame
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
    
    final nombreController = ref.read(petNombreControllerProvider);
    final razaController = ref.read(petRazaControllerProvider);
    final edadController = ref.read(petEdadControllerProvider);
    final pesoController = ref.read(petPesoControllerProvider);
    final colorController = ref.read(petColorControllerProvider);
    final observacionesController = ref.read(petObservacionesControllerProvider);

    nombreController.text = widget.pet.nombre;
    razaController.text = widget.pet.raza ?? '';
    edadController.text = widget.pet.edad?.toString() ?? '';
    pesoController.text = widget.pet.peso?.toString() ?? '';
    colorController.text = widget.pet.color ?? '';
    observacionesController.text = widget.pet.observaciones ?? '';

    // Establecer valores de dropdowns usando Future.microtask para evitar modificar durante build
    Future.microtask(() {
      if (mounted) {
        ref.read(selectedOwnerIdProvider.notifier).state = widget.pet.propietarioId;
        ref.read(selectedTamanoProvider.notifier).state = widget.pet.tamano;
        ref.read(selectedNivelEnergiaProvider.notifier).state = widget.pet.nivelEnergia;
      }
    });

    _initialized = true;
  }

  Future<void> _handleUpdate(BuildContext context, WidgetRef ref) async {
    print('_handleUpdate: Iniciando actualización...');
    
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
      print('_handleUpdate: Usuario es null');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error: No hay usuario autenticado'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    // Obtener el propietario seleccionado del estado
    var selectedOwnerId = ref.read(selectedOwnerIdProvider);
    // Si no hay propietario seleccionado, usar el propietario original del canino
    if (selectedOwnerId == null) {
      print('_handleUpdate: Propietario no seleccionado, usando propietario original: ${widget.pet.propietarioId}');
      selectedOwnerId = widget.pet.propietarioId;
    }
    
    if (selectedOwnerId.isEmpty) {
      print('_handleUpdate: Propietario ID vacío');
      final formController = ref.read(petFormControllerProvider.notifier);
      formController.setMessage('Debes seleccionar un propietario', Colors.red.shade700);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Debes seleccionar un propietario'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    if (!formKey.currentState!.validate()) {
      print('_handleUpdate: Validación del formulario falló');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Por favor, completa todos los campos requeridos'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    if (!context.mounted) {
      print('_handleUpdate: Context no está montado');
      return;
    }

    print('_handleUpdate: Pasando validaciones, iniciando actualización...');

    final formController = ref.read(petFormControllerProvider.notifier);
    formController.setMessage('Actualizando canino...', Colors.blue.shade700);
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

      await ref.read(petControllerProvider.notifier).updatePet(
            paseadorId: user.uid,
            petId: widget.pet.id,
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
            foto: widget.pet.foto, // Preservar foto existente
          );

      // Invalidar el provider para refrescar la lista
      Future.microtask(() {
        if (mounted) {
          ref.invalidate(petsListProvider(user.uid));
        }
      });

      formController.setMessage('¡Datos modificados exitosamente!', AppColors.button);
      formController.setLoading(false);

      // Esperar un momento para mostrar el mensaje de éxito
      await Future.delayed(const Duration(milliseconds: 1500));

      if (context.mounted) {
        // Mostrar snackbar adicional para confirmar la modificación
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Los datos del canino han sido modificados correctamente'),
            backgroundColor: AppColors.button,
            duration: Duration(seconds: 2),
          ),
        );
        
        Navigator.pop(context, true); // Retornar true para indicar que se actualizó
      }
    } catch (e) {
      formController.setMessage('Error: ${e.toString()}', Colors.red.shade700);
      formController.setLoading(false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
    // Verificar si está cargando: formState.isLoading o petState está en estado loading
    final isLoading = formState.isLoading || petState.isLoading;

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
                    'Modificar Canino',
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
                      // Selector de Propietario
                      ownersAsync.when(
                        data: (owners) {
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
                        icon: Icons.color_lens_outlined,
                        label: 'Color (Opcional)',
                        controller: colorController,
                      ),
                      const SizedBox(height: 12),
                      AppInput(
                        icon: Icons.notes,
                        label: 'Observaciones (Opcional)',
                        controller: observacionesController,
                        keyboardType: TextInputType.multiline,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Botón de Actualización
                if (isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else
                  AppButton(
                    text: 'ACTUALIZAR CANINO',
                    onPressed: () {
                      print('Botón ACTUALIZAR CANINO presionado. isLoading: $isLoading');
                      _handleUpdate(context, ref);
                    },
                    isLoading: false,
                    icon: const Icon(Icons.save, size: 20, color: AppColors.white),
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

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey[400]!, width: 1),
        ),
      ),
      child: DropdownButtonFormField<Owner>(
        value: owners.firstWhere(
          (owner) => owner.id == (selectedOwnerId ?? widget.pet.propietarioId),
          orElse: () => owners.first,
        ),
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
              '${owner.nombre} - ${owner.ci.replaceAll(' LP', '')}',
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
    final List<String> tamanos = ['pequeño', 'mediano', 'grande'];

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
    final selectedNivelEnergia = ref.watch(selectedNivelEnergiaProvider);
    final List<String> niveles = ['bajo', 'medio', 'alto'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey[400]!, width: 1),
        ),
      ),
      child: DropdownButtonFormField<String>(
        value: selectedNivelEnergia,
        decoration: InputDecoration(
          labelText: 'Nivel de Energía (Opcional)',
          labelStyle: TextStyle(
            color: Colors.grey[500],
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: Icon(Icons.battery_charging_full, color: Colors.grey[400], size: 20),
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
    
    // Obtener el propietario seleccionado o el propietario original del canino
    final currentOwnerId = selectedOwnerId ?? widget.pet.propietarioId;
    final selectedOwner = owners.firstWhere(
      (owner) => owner.id == currentOwnerId,
      orElse: () => owners.isNotEmpty ? owners.first : owners.first,
    );

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
        key: ValueKey(currentOwnerId), // Forzar reconstrucción cuando cambie el propietario
        initialValue: ciNumber,
        enabled: false,
        decoration: InputDecoration(
          labelText: 'CI del Propietario',
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

