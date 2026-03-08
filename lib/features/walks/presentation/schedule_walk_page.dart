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
      // Forzar recarga de paseos del día seleccionado para que los horarios se calculen con datos frescos.
      final user = ref.read(authControllerProvider).value;
      if (user != null) {
        final day = DateTime(picked.year, picked.month, picked.day);
        ref.invalidate(walksByDateProvider(WalksByDateParams(paseadorId: user.uid, date: day)));
      }
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

  /// Opciones de hora de fin: desde inicio+30 min hasta 23:00 cada 30 min.
  /// La lista final se filtra con [ScheduleAvailabilityService.verificarDisponibilidadHorario]
  /// usando los paseos del día (Riverpod) para no ofrecer franjas ya ocupadas.
  List<String> _getHorariosFinDisponibles(String? horaInicio) {
    if (horaInicio == null) return [];

    final partesInicio = horaInicio.split(':');
    final horaInicioInt = int.parse(partesInicio[0]);
    final minutoInicioInt = partesInicio.length > 1 ? int.parse(partesInicio[1]) : 0;
    final inicioTotalMinutos = horaInicioInt * 60 + minutoInicioInt;

    final horariosFin = <String>[];
    for (int minutos = inicioTotalMinutos + 30; minutos <= 23 * 60; minutos += 30) {
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
            content: Text('Faltan datos, completá todos los campos.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    // Traemos el perro y el propietario
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

    // Revisamos si el horario está libre (si estamos offline puede fallar, pero seguimos igual)
    List<Walk> walksExistentes = [];
    try {
      final repository = ref.read(walksRepositoryProvider);
      walksExistentes = await repository.getWalksByPaseadorIdAndDate(
        user.uid,
        formState.selectedDate,
      ).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          // Sin conexión devolvemos vacío y usamos lo que haya en caché
          return <Walk>[];
        },
      );
    } catch (e) {
      // Sin conexión seguimos con lista vacía; el paseo se guarda local y después sincroniza
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
            content: Text('Ese horario ya está ocupado, elegí otro.'),
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
          throw TimeoutException('Sin conexión. El paseo quedó guardado y se subirá cuando haya internet.');
        },
      );

      // Invalidar providers de Riverpod para que, al programar otro paseo el mismo día,
      // los horarios ya ocupados (ej. 21:30–22:00) no aparezcan en el dropdown.
      Future.delayed(const Duration(milliseconds: 300), () {
        ref.invalidate(walksByDateProvider(
          WalksByDateParams(paseadorId: user.uid, date: formState.selectedDate),
        ));
        ref.invalidate(walksByDateAllStatusProvider(
          WalksByDateParams(paseadorId: user.uid, date: formState.selectedDate),
        ));
        // Si eligió otra fecha, también refrescamos hoy
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
            content: Text('Listo, paseo programado.'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context);
      }
    } on TimeoutException {
      // Guardó local; refrescamos la lista igual
      final formState = ref.read(scheduleWalkFormControllerProvider);
      Future.delayed(const Duration(milliseconds: 300), () {
        ref.invalidate(walksByDateProvider(
          WalksByDateParams(paseadorId: user.uid, date: formState.selectedDate),
        ));
        ref.invalidate(walksByDateAllStatusProvider(
          WalksByDateParams(paseadorId: user.uid, date: formState.selectedDate),
        ));
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
            content: Text('Paseo guardado. Se subirá cuando haya conexión.'),
            backgroundColor: AppColors.warning,
            duration: const Duration(seconds: 3),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Pasó algo: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
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
                // Ícono
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

                // Fecha
                _buildDateInput(),

                const SizedBox(height: 12),

                // Hora inicio
                _buildHoraInicioInput(paseadorId),

                const SizedBox(height: 12),

                // Hora fin
                _buildHoraFinInput(),

                const SizedBox(height: 12),

                // Perro
                _buildPetInput(paseadorId),

                const SizedBox(height: 12),

                // Lugar de recojo
                AppInput(
                  icon: Icons.location_on_outlined,
                  label: 'Lugar de Recojo',
                  controller: _direccionController,
                  keyboardType: TextInputType.streetAddress,
                ),

                const SizedBox(height: 12),

                // Precio del paseo
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

                // Guardar
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

    // Riverpod: paseos del día seleccionado (solo día, sin hora) para no mostrar horarios ocupados.
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
        final fechaDia = DateTime(selectedStart.year, selectedStart.month, selectedStart.day);
        final disponibilidad = ScheduleAvailabilityService.calcularDisponibilidad(
          paseosExistentes: walks,
          fecha: fechaDia,
        );
        final disponiblesSet = disponibilidad
            .where((h) => h.disponible)
            .map((h) => h.horaInicio)
            .toSet();
        var horariosDisponibles = ScheduleAvailabilityService.generarHorariosInicio()
            .where((h) => disponiblesSet.contains(h))
            .toList();

        // Solo cuando es fecha actual: habilitar únicamente horarios posteriores a la hora actual.
        if (isToday) {
          final nowMinutes = now.hour * 60 + now.minute;
          horariosDisponibles = horariosDisponibles
              .where((h) => ScheduleAvailabilityService.horaAMinutos(h) > nowMinutes)
              .toList();
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

        // Si la hora seleccionada ya no está en la lista.
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

    // Misma fuente Riverpod que hora inicio: paseos del día seleccionado (solo día).
    final selectedDayFin = DateTime(formState.selectedDate.year, formState.selectedDate.month, formState.selectedDate.day);
    final walksAsync = ref.watch(walksByDateProvider(
      WalksByDateParams(paseadorId: paseadorId, date: selectedDayFin),
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

        // Rango hasta 23:00. Excluir horarios sin disponibilidad (ocupados).
        var horariosFinDisponibles = horariosFinCandidatos.where((horaFin) {
          return ScheduleAvailabilityService.verificarDisponibilidadHorario(
            paseosExistentes: walks,
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
            // Perro y propietario del formulario
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
                
                // Si el propietario tiene dirección, la cargamos
                final direccionPropietario = selectedOwner.direccion;
                if (direccionPropietario != null && direccionPropietario.isNotEmpty) {
                  // Solo si no tocó la dirección a mano
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
                    // Al cambiar el perro limpiamos la dirección
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
