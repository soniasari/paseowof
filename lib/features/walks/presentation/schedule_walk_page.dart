import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_input.dart';
import '../../../core/constants/app_colors.dart';
import '../../owners_pets/domain/entities/pet.dart';
import '../../owners_pets/domain/entities/owner.dart';
import '../../owners_pets/presentation/providers/owner_pet_providers.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import 'package:paseowof/features/walks/domain/entities/walk.dart';
import 'controllers/walks_controller.dart';
import 'controllers/schedule_walk_form_controller.dart';
import 'providers/walks_providers.dart';
import 'utils/schedule_availability_service.dart';

class ScheduleWalkPage extends ConsumerStatefulWidget {
  const ScheduleWalkPage({super.key});

  @override
  ConsumerState<ScheduleWalkPage> createState() => _ScheduleWalkPageState();
}

class _ScheduleWalkPageState extends ConsumerState<ScheduleWalkPage> {
  final TextEditingController _direccionController = TextEditingController();
  final TextEditingController _fechaController = TextEditingController();
  final TextEditingController _precioController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final formState = ref.read(scheduleWalkFormControllerProvider);
    _fechaController.text = '${formState.selectedDate.day.toString().padLeft(2, '0')}/${formState.selectedDate.month.toString().padLeft(2, '0')}/${formState.selectedDate.year}';
  }

  @override
  void dispose() {
    _direccionController.dispose();
    _fechaController.dispose();
    _precioController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    if (!mounted) return;
    
    final formState = ref.read(scheduleWalkFormControllerProvider);
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: formState.selectedDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );

    if (picked != null && mounted) {
      final controller = ref.read(scheduleWalkFormControllerProvider.notifier);
      controller.setSelectedDate(picked);
      _fechaController.text = '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
    }
  }

  void _selectHoraInicio(String? horaInicio) {
    final controller = ref.read(scheduleWalkFormControllerProvider.notifier);
    controller.setHoraInicio(horaInicio);
  }

  void _selectHoraFin(String? horaFin) {
    final controller = ref.read(scheduleWalkFormControllerProvider.notifier);
    controller.setHoraFin(horaFin);
  }

  List<String> _getHorariosFinDisponibles(String? horaInicio) {
    if (horaInicio == null) {
      return [];
    }

    final partesInicio = horaInicio.split(':');
    final horaInicioInt = int.parse(partesInicio[0]);
    final minutoInicioInt = partesInicio.length > 1 ? int.parse(partesInicio[1]) : 0;
    final inicioTotalMinutos = horaInicioInt * 60 + minutoInicioInt;
    
    // Generar horarios de fin con intervalos de 30 minutos
    // Empezar 30 minutos después de la hora inicio, hasta las 19:00
    final horariosFin = <String>[];
    for (int minutos = inicioTotalMinutos + 30; minutos <= 19 * 60; minutos += 30) {
      final hora = minutos ~/ 60;
      final minuto = minutos % 60;
      horariosFin.add('${hora.toString().padLeft(2, '0')}:${minuto.toString().padLeft(2, '0')}');
    }
    return horariosFin;
  }

  Future<void> _handleScheduleWalk() async {
    final authState = ref.read(authControllerProvider);
    final user = authState.value;
    if (user == null) return;

    final formState = ref.read(scheduleWalkFormControllerProvider);
    if (formState.horaInicio == null || formState.horaFin == null || formState.selectedCaninoId == null || _direccionController.text.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Completa todos los campos requeridos'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    // Obtener datos del perro y propietario
    final petsAsync = ref.read(petsListProvider(user.uid));
    final pets = petsAsync.value ?? [];
    if (pets.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No hay perros registrados'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    final pet = pets.firstWhere(
      (p) => p.id == formState.selectedCaninoId,
      orElse: () => pets.first,
    );

    final ownersAsync = ref.read(ownersListProvider(user.uid));
    final owners = ownersAsync.value ?? [];
    if (owners.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No hay propietarios registrados'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    final owner = owners.firstWhere(
      (o) => o.id == pet.propietarioId,
      orElse: () => owners.first,
    );

    // Calcular duración en minutos
    final partesInicio = formState.horaInicio!.split(':');
    final partesFin = formState.horaFin!.split(':');
    final inicioMinutes = int.parse(partesInicio[0]) * 60 + int.parse(partesInicio[1]);
    final finMinutes = int.parse(partesFin[0]) * 60 + int.parse(partesFin[1]);
    final duracionMinutos = finMinutes - inicioMinutes;

    if (duracionMinutos <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('La hora de fin debe ser posterior a la hora de inicio'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    // Verificar disponibilidad final antes de guardar
    // En modo offline, esta verificación puede fallar, pero permitimos continuar
    List<Walk> walksExistentes = [];
    try {
      final repository = ref.read(walksRepositoryProvider);
      walksExistentes = await repository.getWalksByPaseadorIdAndDate(
        user.uid,
        formState.selectedDate,
      ).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          // Si hay timeout (sin conexión), retornar lista vacía
          // La verificación de disponibilidad se hará solo con datos locales
          return <Walk>[];
        },
      );
    } catch (e) {
      // Si falla la verificación (sin conexión), usar lista vacía
      // Esto permite continuar con la programación en modo offline
      // Los datos se guardarán localmente y se sincronizarán cuando haya conexión
      walksExistentes = [];
    }

    final estaDisponible = ScheduleAvailabilityService.verificarDisponibilidadHorario(
      paseosExistentes: walksExistentes,
      fecha: formState.selectedDate,
      horaInicio: formState.horaInicio!,
      horaFin: formState.horaFin!,
    );

    if (!estaDisponible) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Este horario ya está ocupado. Por favor, selecciona otro horario.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    // Guardar el paseo
    try {
      // Parsear precio (aceptar coma o punto como decimal)
      double? precio;
      if (_precioController.text.trim().isNotEmpty) {
        final precioStr = _precioController.text.trim().replaceAll(',', '.');
        precio = double.tryParse(precioStr);
        if (precio == null || precio < 0) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Ingresa un precio válido'),
                backgroundColor: AppColors.error,
              ),
            );
          }
          return;
        }
      }

      await ref.read(walksControllerProvider.notifier).scheduleWalk(
            paseadorId: user.uid,
            propietarioId: owner.id,
            propietarioNombre: owner.nombre,
            fechaPaseo: formState.selectedDate,
            horaInicio: formState.horaInicio!,
            horaFin: formState.horaFin!,
            duracionMinutos: duracionMinutos,
            direccionRecogida: _direccionController.text.trim(),
            caninoIds: [formState.selectedCaninoId!],
            caninoNombres: [pet.nombre],
            observaciones: null,
            precio: precio,
          ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          // Si hay timeout, asumimos que está offline pero los datos se guardaron localmente
          throw TimeoutException('Sin conexión a internet. El paseo se guardó localmente y se sincronizará cuando haya conexión.');
        },
      );

      // Invalidar providers para refrescar la lista de paseos
      // Usar un pequeño delay para asegurar que Firestore haya actualizado su caché local
      Future.delayed(const Duration(milliseconds: 300), () {
        // Invalidar provider de la fecha seleccionada
        ref.invalidate(walksByDateProvider(
          WalksByDateParams(paseadorId: user.uid, date: formState.selectedDate),
        ));
        // Invalidar provider de todos los estados para la fecha seleccionada
        ref.invalidate(walksByDateAllStatusProvider(
          WalksByDateParams(paseadorId: user.uid, date: formState.selectedDate),
        ));
        // Si la fecha seleccionada es diferente a hoy, también invalidar hoy
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final selectedDateNormalized = DateTime(
          formState.selectedDate.year,
          formState.selectedDate.month,
          formState.selectedDate.day,
        );
        if (!selectedDateNormalized.isAtSameMomentAs(today)) {
          ref.invalidate(walksByDateAllStatusProvider(
            WalksByDateParams(paseadorId: user.uid, date: today),
          ));
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Paseo programado exitosamente!'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context);
      }
    } on TimeoutException {
      // Manejar timeout - los datos se guardaron localmente
      // Invalidar providers para refrescar la lista de paseos (incluyendo los locales)
      // Usar un pequeño delay para asegurar que Firestore haya actualizado su caché local
      final formState = ref.read(scheduleWalkFormControllerProvider);
      Future.delayed(const Duration(milliseconds: 300), () {
        // Invalidar provider de la fecha seleccionada
        ref.invalidate(walksByDateProvider(
          WalksByDateParams(paseadorId: user.uid, date: formState.selectedDate),
        ));
        // Invalidar provider de todos los estados para la fecha seleccionada
        ref.invalidate(walksByDateAllStatusProvider(
          WalksByDateParams(paseadorId: user.uid, date: formState.selectedDate),
        ));
        // Si la fecha seleccionada es diferente a hoy, también invalidar hoy
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final selectedDateNormalized = DateTime(
          formState.selectedDate.year,
          formState.selectedDate.month,
          formState.selectedDate.day,
        );
        if (!selectedDateNormalized.isAtSameMomentAs(today)) {
          ref.invalidate(walksByDateAllStatusProvider(
            WalksByDateParams(paseadorId: user.uid, date: today),
          ));
        }
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Paseo guardado localmente. Se sincronizará cuando haya conexión.'),
            backgroundColor: AppColors.warning,
            duration: const Duration(seconds: 3),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      // Verificar si es un error de red (offline)
      final errorMessage = e.toString().toLowerCase();
      if (errorMessage.contains('network') || 
          errorMessage.contains('unavailable') ||
          errorMessage.contains('deadline') ||
          errorMessage.contains('connection')) {
        // Invalidar providers para refrescar la lista de paseos (incluyendo los locales)
        // Usar un pequeño delay para asegurar que Firestore haya actualizado su caché local
        final formState = ref.read(scheduleWalkFormControllerProvider);
        Future.delayed(const Duration(milliseconds: 300), () {
          ref.invalidate(walksByDateProvider(
            WalksByDateParams(paseadorId: user.uid, date: formState.selectedDate),
          ));
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sin conexión. El paseo se guardó localmente y se sincronizará automáticamente cuando haya internet.'),
              backgroundColor: AppColors.warning,
              duration: Duration(seconds: 3),
            ),
          );
          Navigator.pop(context);
        }
      } else {
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
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final user = authState.value;
    final paseadorId = user?.uid ?? '';

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
                    'Programar Nuevo Paseo',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Bloque 1: Fecha
                _buildDateInput(),

                const SizedBox(height: 12),

                // Bloque 2: Horario de Inicio
                _buildHoraInicioInput(paseadorId),

                const SizedBox(height: 12),

                // Bloque 3: Horario de Fin
                _buildHoraFinInput(),

                const SizedBox(height: 12),

                // Bloque 4: Perro
                _buildPetInput(paseadorId),

                const SizedBox(height: 12),

                // Bloque 5: Lugar de Recojo
                AppInput(
                  icon: Icons.location_on_outlined,
                  label: 'Lugar de Recojo',
                  controller: _direccionController,
                  keyboardType: TextInputType.streetAddress,
                ),

                const SizedBox(height: 12),

                // Bloque 6: Precio del Paseo
                AppInput(
                  icon: Icons.attach_money,
                  label: 'Precio del Paseo',
                  controller: _precioController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value != null && value.isNotEmpty) {
                      final precio = double.tryParse(value);
                      if (precio == null || precio < 0) {
                        return 'Ingresa un precio válido';
                      }
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Botón de guardar
                AppButton(
                  text: 'PROGRAMAR PASEO',
                  onPressed: _handleScheduleWalk,
                  isLoading: ref.watch(walksControllerProvider).isLoading,
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
                      Icons.calendar_today,
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

  Widget _buildDateInput() {
    return GestureDetector(
      onTap: _selectDate,
      child: AbsorbPointer(
        child: AppInput(
          icon: Icons.calendar_today_outlined,
          label: 'Fecha del Paseo',
          controller: _fechaController,
        ),
      ),
    );
  }

  Widget _buildHoraInicioInput(String paseadorId) {
    final formState = ref.watch(scheduleWalkFormControllerProvider);
    final authState = ref.watch(authControllerProvider);
    final user = authState.value;
    final paseadorIdValue = user?.uid ?? '';

    // Obtener paseos existentes para la fecha
    final walksAsync = ref.watch(walksByDateProvider(
      WalksByDateParams(paseadorId: paseadorIdValue, date: formState.selectedDate),
    ));

    return walksAsync.when(
      data: (walks) {
        // Calcular disponibilidad
        final disponibilidad = ScheduleAvailabilityService.calcularDisponibilidad(
          paseosExistentes: walks,
          fecha: formState.selectedDate,
        );

        // Filtrar solo los horarios disponibles
        final horariosDisponibles = disponibilidad
            .where((h) => h.disponible)
            .map((h) => h.horaInicio)
            .toList();

        if (horariosDisponibles.isEmpty) {
          return DropdownButtonFormField<String>(
            value: null,
            decoration: InputDecoration(
              labelText: 'Hora de Inicio',
              labelStyle: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              floatingLabelBehavior: FloatingLabelBehavior.auto,
              prefixIcon: Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Icon(
                  Icons.access_time,
                  color: Colors.grey.shade400,
                  size: 20,
                ),
              ),
              prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
              contentPadding: const EdgeInsets.only(top: 24, bottom: 8),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(
                  color: Colors.grey.shade300,
                  width: 1.0,
                ),
              ),
              isDense: true,
            ),
            items: const [],
            onChanged: null,
            hint: const Text('No hay horarios disponibles'),
          );
        }

        return DropdownButtonFormField<String>(
          value: formState.horaInicio,
          decoration: InputDecoration(
            labelText: 'Hora de Inicio',
            labelStyle: TextStyle(
              color: formState.horaInicio == null
                  ? Colors.grey.shade500
                  : AppColors.button.withOpacity(0.8),
              fontSize: formState.horaInicio == null ? 16 : 12,
              fontWeight: FontWeight.w500,
            ),
            floatingLabelBehavior: FloatingLabelBehavior.auto,
            prefixIcon: Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Icon(
                Icons.access_time,
                color: Colors.grey.shade400,
                size: 20,
              ),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
            contentPadding: const EdgeInsets.only(top: 24, bottom: 8),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(
                color: Colors.grey.shade300,
                width: 1.0,
              ),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(
                color: AppColors.button,
                width: 2.0,
              ),
            ),
            isDense: true,
          ),
          items: horariosDisponibles.map((hora) {
            return DropdownMenuItem(
              value: hora,
              child: Text(hora),
            );
          }).toList(),
          onChanged: (value) {
            _selectHoraInicio(value);
          },
          hint: const Text('Selecciona un horario'),
        );
      },
      loading: () => DropdownButtonFormField<String>(
        value: null,
        decoration: InputDecoration(
          labelText: 'Hora de Inicio',
          labelStyle: TextStyle(
            color: Colors.grey.shade500,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          floatingLabelBehavior: FloatingLabelBehavior.auto,
          prefixIcon: Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Icon(
              Icons.access_time,
              color: Colors.grey.shade400,
              size: 20,
            ),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
          contentPadding: const EdgeInsets.only(top: 24, bottom: 8),
          enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(
              color: Colors.grey.shade300,
              width: 1.0,
            ),
          ),
          isDense: true,
        ),
        items: const [],
        onChanged: null,
        hint: const Text('Cargando...'),
      ),
      error: (error, stack) => DropdownButtonFormField<String>(
        value: null,
        decoration: InputDecoration(
          labelText: 'Hora de Inicio',
          labelStyle: TextStyle(
            color: Colors.grey.shade500,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          floatingLabelBehavior: FloatingLabelBehavior.auto,
          prefixIcon: Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Icon(
              Icons.access_time,
              color: Colors.grey.shade400,
              size: 20,
            ),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
          contentPadding: const EdgeInsets.only(top: 24, bottom: 8),
          enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(
              color: Colors.grey.shade300,
              width: 1.0,
            ),
          ),
          isDense: true,
        ),
        items: const [],
        onChanged: null,
        hint: Text('Error: ${error.toString()}'),
      ),
    );
  }

  Widget _buildHoraFinInput() {
    final formState = ref.watch(scheduleWalkFormControllerProvider);
    final authState = ref.watch(authControllerProvider);
    final user = authState.value;
    final paseadorId = user?.uid ?? '';

    if (formState.horaInicio == null) {
      return DropdownButtonFormField<String>(
        value: null,
        decoration: InputDecoration(
          labelText: 'Hora de Fin',
          labelStyle: TextStyle(
            color: Colors.grey.shade500,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          floatingLabelBehavior: FloatingLabelBehavior.auto,
          prefixIcon: Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Icon(
              Icons.access_time_filled,
              color: Colors.grey.shade400,
              size: 20,
            ),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
          contentPadding: const EdgeInsets.only(top: 24, bottom: 8),
          enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(
              color: Colors.grey.shade300,
              width: 1.0,
            ),
          ),
          isDense: true,
        ),
        items: const [],
        onChanged: null,
        hint: const Text('Primero selecciona la hora de inicio'),
      );
    }

    // Obtener paseos existentes para la fecha
    final walksAsync = ref.watch(walksByDateProvider(
      WalksByDateParams(paseadorId: paseadorId, date: formState.selectedDate),
    ));

    return walksAsync.when(
      data: (walks) {
        final horariosFinCandidatos = _getHorariosFinDisponibles(formState.horaInicio);
        
        // Filtrar horarios de fin que no se solapen con paseos existentes
        final horariosFinDisponibles = horariosFinCandidatos.where((horaFin) {
          return ScheduleAvailabilityService.verificarDisponibilidadHorario(
            paseosExistentes: walks,
            fecha: formState.selectedDate,
            horaInicio: formState.horaInicio!,
            horaFin: horaFin,
          );
        }).toList();

        return DropdownButtonFormField<String>(
          value: formState.horaFin,
          decoration: InputDecoration(
            labelText: 'Hora de Fin',
            labelStyle: TextStyle(
              color: formState.horaFin == null
                  ? Colors.grey.shade500
                  : AppColors.button.withOpacity(0.8),
              fontSize: formState.horaFin == null ? 16 : 12,
              fontWeight: FontWeight.w500,
            ),
            floatingLabelBehavior: FloatingLabelBehavior.auto,
            prefixIcon: Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Icon(
                Icons.access_time_filled,
                color: Colors.grey.shade400,
                size: 20,
              ),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
            contentPadding: const EdgeInsets.only(top: 24, bottom: 8),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(
                color: Colors.grey.shade300,
                width: 1.0,
              ),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(
                color: AppColors.button,
                width: 2.0,
              ),
            ),
            isDense: true,
          ),
          items: horariosFinDisponibles.map((hora) {
            return DropdownMenuItem(
              value: hora,
              child: Text(hora),
            );
          }).toList(),
          onChanged: horariosFinDisponibles.isEmpty
              ? null
              : (value) {
                  _selectHoraFin(value);
                },
          hint: Text(horariosFinDisponibles.isEmpty
              ? 'No hay horarios disponibles'
              : 'Selecciona un horario'),
        );
      },
      loading: () => DropdownButtonFormField<String>(
        value: null,
        decoration: InputDecoration(
          labelText: 'Hora de Fin',
          labelStyle: TextStyle(
            color: Colors.grey.shade500,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          floatingLabelBehavior: FloatingLabelBehavior.auto,
          prefixIcon: Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Icon(
              Icons.access_time_filled,
              color: Colors.grey.shade400,
              size: 20,
            ),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
          contentPadding: const EdgeInsets.only(top: 24, bottom: 8),
          enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(
              color: Colors.grey.shade300,
              width: 1.0,
            ),
          ),
          isDense: true,
        ),
        items: const [],
        onChanged: null,
        hint: const Text('Cargando...'),
      ),
      error: (error, stack) => DropdownButtonFormField<String>(
        value: null,
        decoration: InputDecoration(
          labelText: 'Hora de Fin',
          labelStyle: TextStyle(
            color: Colors.grey.shade500,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          floatingLabelBehavior: FloatingLabelBehavior.auto,
          prefixIcon: Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Icon(
              Icons.access_time_filled,
              color: Colors.grey.shade400,
              size: 20,
            ),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
          contentPadding: const EdgeInsets.only(top: 24, bottom: 8),
          enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(
              color: Colors.grey.shade300,
              width: 1.0,
            ),
          ),
          isDense: true,
        ),
        items: const [],
        onChanged: null,
        hint: Text('Error: ${error.toString()}'),
      ),
    );
  }

  Widget _buildPetInput(String paseadorId) {
    final petsAsync = ref.watch(petsListProvider(paseadorId));
    final ownersAsync = ref.watch(ownersListProvider(paseadorId));

    return petsAsync.when(
      data: (pets) {
        return ownersAsync.when(
          data: (owners) {
            // Obtener el perro y propietario seleccionados
            Pet? selectedPet;
            Owner? selectedOwner;

            final formStateCanino = ref.watch(scheduleWalkFormControllerProvider);
            if (formStateCanino.selectedCaninoId != null && pets.isNotEmpty) {
              selectedPet = pets.firstWhere(
                (p) => p.id == formStateCanino.selectedCaninoId,
                orElse: () => pets.first,
              );
              if (owners.isNotEmpty) {
                selectedOwner = owners.firstWhere(
                  (o) => o.id == selectedPet!.propietarioId,
                  orElse: () => owners.first,
                );
                
                // Cargar automáticamente la dirección del propietario
                final direccionPropietario = selectedOwner.direccion;
                if (direccionPropietario != null && direccionPropietario.isNotEmpty) {
                  // Solo actualizar si el campo está vacío o si el usuario no lo ha modificado manualmente
                  if (_direccionController.text.isEmpty || 
                      _direccionController.text == formStateCanino.lastLoadedDireccion) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        _direccionController.text = direccionPropietario;
                        ref.read(scheduleWalkFormControllerProvider.notifier).setLastLoadedDireccion(direccionPropietario);
                      }
                    });
                  }
                }
              }
            }

            final formState = ref.watch(scheduleWalkFormControllerProvider);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  value: formState.selectedCaninoId,
                  decoration: InputDecoration(
                    labelText: 'Perro a Pasear',
                    labelStyle: TextStyle(
                      color: formState.selectedCaninoId == null
                          ? Colors.grey.shade500
                          : AppColors.button.withOpacity(0.8),
                      fontSize: formState.selectedCaninoId == null ? 16 : 12,
                      fontWeight: FontWeight.w500,
                    ),
                    floatingLabelBehavior: FloatingLabelBehavior.auto,
                    prefixIcon: Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Icon(
                        Icons.pets,
                        color: Colors.grey.shade400,
                        size: 20,
                      ),
                    ),
                    prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                    contentPadding: const EdgeInsets.only(top: 24, bottom: 8),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(
                        color: Colors.grey.shade300,
                        width: 1.0,
                      ),
                    ),
                    focusedBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(
                        color: AppColors.button,
                        width: 2.0,
                      ),
                    ),
                    isDense: true,
                  ),
                  items: pets.map((pet) {
                    return DropdownMenuItem(
                      value: pet.id,
                      child: Text(pet.nombre),
                    );
                  }).toList(),
                  onChanged: (value) {
                    final controller = ref.read(scheduleWalkFormControllerProvider.notifier);
                    controller.setSelectedCaninoId(value);
                    // Limpiar la dirección cuando cambia el perro
                    _direccionController.clear();
                    controller.clearLastLoadedDireccion();
                  },
                  hint: const Text('Selecciona un perro'),
                ),
                if (selectedPet != null && selectedOwner != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.secondary),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Información del Propietario',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildOwnerInfoRow('Nombre', selectedOwner.nombre),
                        const SizedBox(height: 4),
                        _buildOwnerInfoRow('CI', selectedOwner.ci.replaceAll(' LP', '')),
                      ],
                    ),
                  ),
                ],
              ],
            );
          },
          loading: () => AppInput(
            icon: Icons.pets,
            label: 'Perro a Pasear',
            controller: TextEditingController(),
            enabled: false,
          ),
          error: (error, stack) => AppInput(
            icon: Icons.pets,
            label: 'Perro a Pasear',
            controller: TextEditingController(),
            enabled: false,
          ),
        );
      },
      loading: () => AppInput(
        icon: Icons.pets,
        label: 'Perro a Pasear',
        controller: TextEditingController(),
        enabled: false,
      ),
      error: (error, stack) => AppInput(
        icon: Icons.pets,
        label: 'Perro a Pasear',
        controller: TextEditingController(),
        enabled: false,
      ),
    );
  }

  Widget _buildOwnerInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 60,
          child: Text(
            '$label:',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.textGrey,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textDark,
            ),
          ),
        ),
      ],
    );
  }
}
