import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_input.dart';
import '../../../core/constants/app_colors.dart';
import 'package:paseowof/features/walks/domain/entities/walk.dart';
import 'package:paseowof/features/owners_pets/domain/entities/pet.dart';
import 'package:paseowof/features/owners_pets/domain/entities/owner.dart';
import 'package:paseowof/features/owners_pets/presentation/providers/owner_pet_providers.dart';
import 'package:paseowof/features/auth/presentation/providers/auth_providers.dart';
import 'controllers/reschedule_walk_form_controller.dart';
import 'providers/walks_providers.dart';
import 'utils/schedule_availability_service.dart';

class RescheduleWalkPage extends ConsumerStatefulWidget {
  final Walk walk;
  final String paseadorId;

  const RescheduleWalkPage({
    super.key,
    required this.walk,
    required this.paseadorId,
  });

  @override
  ConsumerState<RescheduleWalkPage> createState() => _RescheduleWalkPageState();
}

class _RescheduleWalkPageState extends ConsumerState<RescheduleWalkPage> {
  final TextEditingController _direccionController = TextEditingController();
  final TextEditingController _fechaController = TextEditingController();
  final TextEditingController _precioController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Cargamos los datos del paseo en los campos
    _direccionController.text = widget.walk.direccionRecogida ?? '';
    _precioController.text = widget.walk.precio?.toString() ?? '';
    _fechaController.text = '${widget.walk.fechaPaseo.day.toString().padLeft(2, '0')}/${widget.walk.fechaPaseo.month.toString().padLeft(2, '0')}/${widget.walk.fechaPaseo.year}';
    
    // Cuando ya esté pintada la pantalla, armamos el estado del formulario
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _initializeFromWalk();
      }
    });
  }

  void _initializeFromWalk() {
    try {
      final controller = ref.read(rescheduleWalkFormControllerProvider(widget.walk.fechaPaseo).notifier);
      
      // Actualizamos fecha, hora inicio y fin
      controller.setSelectedDate(widget.walk.fechaPaseo);
      controller.setHoraInicio(widget.walk.horaInicio);
      controller.setHoraFin(widget.walk.horaFin);
      
      // Traemos el canino de este paseo
      _loadWalkPets(controller);
    } catch (e) {
      // Si falla, probamos de nuevo en el siguiente frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          try {
            final controller = ref.read(rescheduleWalkFormControllerProvider(widget.walk.fechaPaseo).notifier);
            controller.setSelectedDate(widget.walk.fechaPaseo);
            controller.setHoraInicio(widget.walk.horaInicio);
            controller.setHoraFin(widget.walk.horaFin);
            _loadWalkPets(controller);
          } catch (_) {
            // Si falla de nuevo, no hacemos nada
          }
        }
      });
    }
  }

  void _loadWalkPets(RescheduleWalkFormController controller) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) {
        try {
          final walkPetsAsync = ref.read(walkPetsProvider(
            WalkPetsParams(paseadorId: widget.paseadorId, walkId: widget.walk.id),
          ));
          final walkPets = await walkPetsAsync.value;
          if (walkPets != null && walkPets.isNotEmpty && mounted) {
            controller.setSelectedCaninoId(walkPets.first.caninoId);
          }
        } catch (e) {
          // Si falla al cargar los caninos, seguimos igual
        }
      }
    });
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
    
    final formState = ref.read(rescheduleWalkFormControllerProvider(widget.walk.fechaPaseo));
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: formState.selectedDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );

    if (picked != null && mounted) {
      try {
        final controller = ref.read(rescheduleWalkFormControllerProvider(widget.walk.fechaPaseo).notifier);
        controller.setSelectedDate(picked);
        _fechaController.text = '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
        final user = ref.read(authControllerProvider).value;
        if (user != null) {
          final day = DateTime(picked.year, picked.month, picked.day);
          ref.invalidate(walksByDateProvider(WalksByDateParams(paseadorId: user.uid, date: day)));
        }
      } catch (e) {
        _fechaController.text = '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
      }
    }
  }

  void _selectHoraInicio(String? horaInicio) {
    try {
      final controller = ref.read(rescheduleWalkFormControllerProvider(widget.walk.fechaPaseo).notifier);
      controller.setHoraInicio(horaInicio);
    } catch (e) {
      // Si falla no hacemos nada
    }
  }

  void _selectHoraFin(String? horaFin) {
    try {
      final controller = ref.read(rescheduleWalkFormControllerProvider(widget.walk.fechaPaseo).notifier);
      controller.setHoraFin(horaFin);
    } catch (e) {
      // Si falla no hacemos nada
    }
  }

  List<String> _getHorariosFinDisponibles(String? horaInicio) {
    if (horaInicio == null) {
      return [];
    }

    final partesInicio = horaInicio.split(':');
    final horaInicioInt = int.parse(partesInicio[0]);
    final minutoInicioInt = partesInicio.length > 1 ? int.parse(partesInicio[1]) : 0;
    final inicioTotalMinutos = horaInicioInt * 60 + minutoInicioInt;
    
    // Horarios de fin cada 30 min, desde media hora después del inicio hasta las 23:00.
    final horariosFin = <String>[];
    for (int minutos = inicioTotalMinutos + 30; minutos <= 23 * 60; minutos += 30) {
      final hora = minutos ~/ 60;
      final minuto = minutos % 60;
      horariosFin.add('${hora.toString().padLeft(2, '0')}:${minuto.toString().padLeft(2, '0')}');
    }
    return horariosFin;
  }

  Future<void> _handleRescheduleWalk() async {
    final authState = ref.read(authControllerProvider);
    final user = authState.value;
    if (user == null) return;

    final formState = ref.read(rescheduleWalkFormControllerProvider(widget.walk.fechaPaseo));
    if (formState.horaInicio == null || formState.horaFin == null || formState.selectedCaninoId == null || _direccionController.text.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Faltan datos, completá todos los campos.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    // Traemos perro y propietario
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

    // Cuántos minutos dura el paseo
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

    // Revisamos si el horario está libre (sin contar este mismo paseo)
    final repository = ref.read(walksRepositoryProvider);
    final walksExistentes = await repository.getWalksByPaseadorIdAndDate(
      user.uid,
      formState.selectedDate,
    );

    // Excluimos este paseo; misma regla que programar: solapamiento y margen 30 min tras cada paseo.
    final walksParaValidar = walksExistentes.where((w) => w.id != widget.walk.id).toList();

    final estaDisponible = ScheduleAvailabilityService.verificarDisponibilidadHorario(
      paseosExistentes: walksParaValidar,
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

    try {
      // Precio: aceptamos coma o punto (ej. 25,5 o 25.5)
      double? precio;
      if (_precioController.text.trim().isNotEmpty) {
        final precioStr = _precioController.text.trim().replaceAll(',', '.');
        precio = double.tryParse(precioStr);
        if (precio == null || precio < 0) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Poné un precio válido (número).'),
                backgroundColor: AppColors.error,
              ),
            );
          }
          return;
        }
      }

      // Nombres de los caninos del paseo
      final walkPetsAsync = ref.read(walkPetsProvider(
        WalkPetsParams(paseadorId: widget.paseadorId, walkId: widget.walk.id),
      ));
      final walkPets = await walkPetsAsync.value;
      final caninoNombres = walkPets?.map((wp) => wp.nombreCanino).toList() ?? [];

      await ref.read(walksControllerProvider.notifier).rescheduleWalk(
            paseadorId: user.uid,
            walkId: widget.walk.id,
            propietarioNombre: owner.nombre,
            nuevaFechaPaseo: formState.selectedDate,
            nuevaHoraInicio: formState.horaInicio!,
            nuevaHoraFin: formState.horaFin!,
            nuevaDuracionMinutos: duracionMinutos,
            nuevaDireccionRecogida: _direccionController.text.trim(),
            caninoNombres: caninoNombres,
            nuevoPrecio: precio,
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
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final selectedDateNormalized = DateTime(
          formState.selectedDate.year,
          formState.selectedDate.month,
          formState.selectedDate.day,
        );
        final originalDateNormalized = DateTime(
          widget.walk.fechaPaseo.year,
          widget.walk.fechaPaseo.month,
          widget.walk.fechaPaseo.day,
        );
        
        // Invalidar provider de la nueva fecha
        ref.invalidate(walksByDateProvider(
          WalksByDateParams(paseadorId: user.uid, date: formState.selectedDate),
        ));
        ref.invalidate(walksByDateAllStatusProvider(
          WalksByDateParams(paseadorId: user.uid, date: formState.selectedDate),
        ));
        
        // Invalidar provider de la fecha original (si es diferente a la nueva)
        if (!selectedDateNormalized.isAtSameMomentAs(originalDateNormalized)) {
          ref.invalidate(walksByDateProvider(
            WalksByDateParams(paseadorId: user.uid, date: widget.walk.fechaPaseo),
          ));
          ref.invalidate(walksByDateAllStatusProvider(
            WalksByDateParams(paseadorId: user.uid, date: widget.walk.fechaPaseo),
          ));
        }
        
        // Invalidar provider de hoy si la fecha original o nueva es hoy
        if (originalDateNormalized.isAtSameMomentAs(today) || 
            selectedDateNormalized.isAtSameMomentAs(today)) {
          ref.invalidate(walksByDateAllStatusProvider(
            WalksByDateParams(paseadorId: user.uid, date: today),
          ));
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Listo, paseo reprogramado.'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context);
      }
    } on TimeoutException {
      // Manejar timeout - los datos se guardaron localmente
      // Invalidar providers para refrescar la lista de paseos (incluyendo los locales)
      final formState = ref.read(rescheduleWalkFormControllerProvider(widget.walk.fechaPaseo));
      Future.delayed(const Duration(milliseconds: 300), () {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final selectedDateNormalized = DateTime(
          formState.selectedDate.year,
          formState.selectedDate.month,
          formState.selectedDate.day,
        );
        final originalDateNormalized = DateTime(
          widget.walk.fechaPaseo.year,
          widget.walk.fechaPaseo.month,
          widget.walk.fechaPaseo.day,
        );
        
        // Invalidar provider de la nueva fecha
        ref.invalidate(walksByDateProvider(
          WalksByDateParams(paseadorId: user.uid, date: formState.selectedDate),
        ));
        ref.invalidate(walksByDateAllStatusProvider(
          WalksByDateParams(paseadorId: user.uid, date: formState.selectedDate),
        ));
        
        // Invalidar provider de la fecha original (si es diferente a la nueva)
        if (!selectedDateNormalized.isAtSameMomentAs(originalDateNormalized)) {
          ref.invalidate(walksByDateProvider(
            WalksByDateParams(paseadorId: user.uid, date: widget.walk.fechaPaseo),
          ));
          ref.invalidate(walksByDateAllStatusProvider(
            WalksByDateParams(paseadorId: user.uid, date: widget.walk.fechaPaseo),
          ));
        }
        
        // Invalidar provider de hoy si la fecha original o nueva es hoy
        if (originalDateNormalized.isAtSameMomentAs(today) || 
            selectedDateNormalized.isAtSameMomentAs(today)) {
          ref.invalidate(walksByDateAllStatusProvider(
            WalksByDateParams(paseadorId: user.uid, date: today),
          ));
        }
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Paseo guardado. Se subirá cuando haya conexión.'),
            backgroundColor: AppColors.warning,
            duration: Duration(seconds: 3),
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
        final formState = ref.read(rescheduleWalkFormControllerProvider(widget.walk.fechaPaseo));
        Future.delayed(const Duration(milliseconds: 300), () {
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          final selectedDateNormalized = DateTime(
            formState.selectedDate.year,
            formState.selectedDate.month,
            formState.selectedDate.day,
          );
          final originalDateNormalized = DateTime(
            widget.walk.fechaPaseo.year,
            widget.walk.fechaPaseo.month,
            widget.walk.fechaPaseo.day,
          );
          
          // Invalidar provider de la nueva fecha
          ref.invalidate(walksByDateProvider(
            WalksByDateParams(paseadorId: user.uid, date: formState.selectedDate),
          ));
          ref.invalidate(walksByDateAllStatusProvider(
            WalksByDateParams(paseadorId: user.uid, date: formState.selectedDate),
          ));
          
          // Invalidar provider de la fecha original (si es diferente a la nueva)
          if (!selectedDateNormalized.isAtSameMomentAs(originalDateNormalized)) {
            ref.invalidate(walksByDateProvider(
              WalksByDateParams(paseadorId: user.uid, date: widget.walk.fechaPaseo),
            ));
            ref.invalidate(walksByDateAllStatusProvider(
              WalksByDateParams(paseadorId: user.uid, date: widget.walk.fechaPaseo),
            ));
          }
          
          // Invalidar provider de hoy si la fecha original o nueva es hoy
          if (originalDateNormalized.isAtSameMomentAs(today) || 
              selectedDateNormalized.isAtSameMomentAs(today)) {
            ref.invalidate(walksByDateAllStatusProvider(
              WalksByDateParams(paseadorId: user.uid, date: today),
            ));
          }
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sin conexión. El paseo quedó guardado y se subirá cuando haya internet.'),
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
        backgroundColor: AppColors.button,
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
                Image.asset(
                  'images/dog.png',
                  width: 40,
                  height: 40,
                ),
                const SizedBox(height: 8),
                const Center(
                  child: Text(
                    'Reprogramar Paseo',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Fecha
                _buildDateInput(),

                const SizedBox(height: 12),

                // Horario de Inicio
                _buildHoraInicioInput(paseadorId),

                const SizedBox(height: 12),

                // Horario de Fin
                _buildHoraFinInput(paseadorId),

                const SizedBox(height: 12),

                // Perro (solo lectura, no se puede cambiar)
                _buildPetInput(paseadorId),

                const SizedBox(height: 12),

                // Lugar de Recojo
                AppInput(
                  icon: Icons.location_on_outlined,
                  label: 'Lugar de Recojo',
                  controller: _direccionController,
                  keyboardType: TextInputType.streetAddress,
                ),

                const SizedBox(height: 12),

                // Precio del Paseo
                AppInput(
                  icon: Icons.attach_money,
                  label: 'Precio del Paseo',
                  controller: _precioController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value != null && value.isNotEmpty) {
                      final precio = double.tryParse(value);
                      if (precio == null || precio < 0) {
                        return 'Poné un precio válido (número).';
                      }
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Botón de guardar
                AppButton(
                  text: 'REPROGRAMAR PASEO',
                  onPressed: _handleRescheduleWalk,
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
                      Icons.update,
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
    final formState = ref.watch(rescheduleWalkFormControllerProvider(widget.walk.fechaPaseo));
    final authState = ref.watch(authControllerProvider);
    final user = authState.value;
    final paseadorIdValue = user?.uid ?? '';

    // Si no hay paseadorId, mostrar un dropdown deshabilitado
    if (paseadorIdValue.isEmpty) {
      return DropdownButtonFormField<String>(
        value: formState.horaInicio,
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
      );
    }

    // Fecha del día seleccionado (sin hora) para pedir paseos y calcular disponibilidad.
    final selectedDay = DateTime(formState.selectedDate.year, formState.selectedDate.month, formState.selectedDate.day);
    final walksAsync = ref.watch(walksByDateProvider(
      WalksByDateParams(paseadorId: paseadorIdValue, date: selectedDay),
    ));

    return walksAsync.when(
      data: (walks) {
        final now = DateTime.now();
        final todayStart = DateTime(now.year, now.month, now.day);
        final selectedStart = DateTime(
          formState.selectedDate.year,
          formState.selectedDate.month,
          formState.selectedDate.day,
        );
        final isToday = selectedStart.isAtSameMomentAs(todayStart);

        // Rango completo 07:00–22:30. Partir del rango total y quedarse solo con los que tienen disponibilidad.
        final walksParaValidar = walks.where((w) => w.id != widget.walk.id).toList();
        final disponibilidad = ScheduleAvailabilityService.calcularDisponibilidad(
          paseosExistentes: walksParaValidar,
          fecha: selectedDay,
        );
        final disponiblesSet = disponibilidad
            .where((h) => h.disponible)
            .map((h) => h.horaInicio)
            .toSet();
        var horariosDisponibles = ScheduleAvailabilityService.generarHorariosInicio()
            .where((h) => disponiblesSet.contains(h))
            .toList();

        // Solo cuando es fecha actual: habilitar únicamente horarios posteriores a la hora actual.
        final nowMinutes = now.hour * 60 + now.minute;
        if (isToday) {
          horariosDisponibles = horariosDisponibles
              .where((h) => ScheduleAvailabilityService.horaAMinutos(h) > nowMinutes)
              .toList();
        }
        // Solo mostrar horas de inicio que tengan al menos una hora de fin válida (evita "No hay horarios disponibles").
        horariosDisponibles = horariosDisponibles.where((horaInicio) {
          final candidatosFin = _getHorariosFinDisponibles(horaInicio);
          return candidatosFin.any((horaFin) =>
                ScheduleAvailabilityService.verificarDisponibilidadHorario(
                  paseosExistentes: walksParaValidar,
                  fecha: selectedDay,
                  horaInicio: horaInicio,
                  horaFin: horaFin,
                ));
        }).toList();
        // Si el horario actual del paseo no está en la lista pero tiene al menos un fin válido (y si es hoy, que sea posterior a ahora), incluirlo.
        if (formState.horaInicio != null && !horariosDisponibles.contains(formState.horaInicio)) {
          if (isToday && ScheduleAvailabilityService.horaAMinutos(formState.horaInicio!) <= nowMinutes) {
            // No añadir: ya pasó.
          } else {
            final candidatosFin = _getHorariosFinDisponibles(formState.horaInicio);
            final tieneFinValido = candidatosFin.any((horaFin) =>
                ScheduleAvailabilityService.verificarDisponibilidadHorario(
                    paseosExistentes: walksParaValidar,
                    fecha: selectedDay,
                    horaInicio: formState.horaInicio!,
                    horaFin: horaFin,
                  ));
            if (tieneFinValido) {
              horariosDisponibles.add(formState.horaInicio!);
              horariosDisponibles.sort();
            }
          }
        }

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

        // Si la hora seleccionada ya no está en la lista filtrada (ej. se tenía 07:00 y ahora es de noche), valor en blanco.
        final valorHoraInicio = horariosDisponibles.contains(formState.horaInicio)
            ? formState.horaInicio
            : null;

        return DropdownButtonFormField<String>(
          value: valorHoraInicio,
          decoration: InputDecoration(
            labelText: 'Hora de Inicio',
            labelStyle: TextStyle(
              color: valorHoraInicio == null
                  ? Colors.grey.shade500
                  : AppColors.button.withOpacity(0.8),
              fontSize: valorHoraInicio == null ? 16 : 12,
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
      loading: () {
        final formStateLoading = ref.watch(rescheduleWalkFormControllerProvider(widget.walk.fechaPaseo));
        return DropdownButtonFormField<String>(
          value: formStateLoading.horaInicio,
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
        );
      },
      error: (error, stack) {
        final formStateError = ref.watch(rescheduleWalkFormControllerProvider(widget.walk.fechaPaseo));
        return DropdownButtonFormField<String>(
          value: formStateError.horaInicio,
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
        );
      },
    );
  }

  Widget _buildHoraFinInput(String paseadorId) {
    final formState = ref.watch(rescheduleWalkFormControllerProvider(widget.walk.fechaPaseo));
    final authState = ref.watch(authControllerProvider);
    final user = authState.value;
    final paseadorIdValue = user?.uid ?? '';

    if (formState.horaInicio == null) {
      return DropdownButtonFormField<String>(
        value: formState.horaFin,
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

    // Si no hay paseadorId, mostrar un dropdown deshabilitado
    if (paseadorIdValue.isEmpty) {
      return DropdownButtonFormField<String>(
        value: formState.horaFin,
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
      );
    }

    final selectedDayFin = DateTime(formState.selectedDate.year, formState.selectedDate.month, formState.selectedDate.day);
    final walksAsync = ref.watch(walksByDateProvider(
      WalksByDateParams(paseadorId: paseadorIdValue, date: selectedDayFin),
    ));

    return walksAsync.when(
      data: (walks) {
        final horariosFinCandidatos = _getHorariosFinDisponibles(formState.horaInicio);

        final now = DateTime.now();
        final todayStart = DateTime(now.year, now.month, now.day);
        final selectedStart = DateTime(
          formState.selectedDate.year,
          formState.selectedDate.month,
          formState.selectedDate.day,
        );
        final isToday = selectedStart.isAtSameMomentAs(todayStart);

        // Rango hasta 23:00. Excluir horarios sin disponibilidad (ocupados); excluimos este paseo.
        final walksParaValidar = walks.where((w) => w.id != widget.walk.id).toList();
        var horariosFinDisponibles = horariosFinCandidatos.where((horaFin) {
          return ScheduleAvailabilityService.verificarDisponibilidadHorario(
            paseosExistentes: walksParaValidar,
            fecha: selectedDayFin,
            horaInicio: formState.horaInicio!,
            horaFin: horaFin,
          );
        }).toList();
        // Solo cuando es fecha actual: solo horarios de fin posteriores a la hora actual.
        if (isToday) {
          final nowMinutes = now.hour * 60 + now.minute;
          horariosFinDisponibles = horariosFinDisponibles
              .where((h) => ScheduleAvailabilityService.horaAMinutos(h) > nowMinutes)
              .toList();
        }

        // Si la hora seleccionada ya no está en la lista filtrada, valor en blanco para que el usuario elija de nuevo.
        final valorHoraFin = horariosFinDisponibles.contains(formState.horaFin)
            ? formState.horaFin
            : null;

        return DropdownButtonFormField<String>(
          value: valorHoraFin,
          decoration: InputDecoration(
            labelText: 'Hora de Fin',
            labelStyle: TextStyle(
              color: valorHoraFin == null
                  ? Colors.grey.shade500
                  : AppColors.button.withOpacity(0.8),
              fontSize: valorHoraFin == null ? 16 : 12,
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
      loading: () {
        final formStateLoading = ref.watch(rescheduleWalkFormControllerProvider(widget.walk.fechaPaseo));
        return DropdownButtonFormField<String>(
          value: formStateLoading.horaFin,
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
      );
      },
      error: (error, stack) {
        final formStateError = ref.watch(rescheduleWalkFormControllerProvider(widget.walk.fechaPaseo));
        return DropdownButtonFormField<String>(
          value: formStateError.horaFin,
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
        );
      },
    );
  }

  Widget _buildPetInput(String paseadorId) {
    final petsAsync = ref.watch(petsListProvider(paseadorId));
    final ownersAsync = ref.watch(ownersListProvider(paseadorId));

    return petsAsync.when(
      data: (pets) {
        return ownersAsync.when(
          data: (owners) {
            Pet? selectedPet;
            Owner? selectedOwner;

            final formStateCanino = ref.watch(rescheduleWalkFormControllerProvider(widget.walk.fechaPaseo));
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
              }
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  value: formStateCanino.selectedCaninoId,
                  decoration: InputDecoration(
                    labelText: 'Perro a Pasear',
                    labelStyle: TextStyle(
                      color: formStateCanino.selectedCaninoId == null
                          ? Colors.grey.shade500
                          : AppColors.button.withOpacity(0.8),
                      fontSize: formStateCanino.selectedCaninoId == null ? 16 : 12,
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
                  onChanged: null, // No se puede cambiar el perro al reprogramar
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

