import 'package:paseowof/features/walks/domain/entities/walk.dart';

/// Modelo para representar el estado de disponibilidad de un horario
class HorarioDisponibilidad {
  final String horaInicio;
  final String horaFin;
  final bool disponible;
  final String? motivoBloqueo;

  HorarioDisponibilidad({
    required this.horaInicio,
    required this.horaFin,
    required this.disponible,
    this.motivoBloqueo,
  });
}

/// Servicio para calcular la disponibilidad de horarios
class ScheduleAvailabilityService {
  /// Genera los horarios disponibles del día (de 7:00 a 18:00, cada 30 minutos)
  static List<String> generarHorarios() {
    final horarios = <String>[];
    for (int hora = 7; hora <= 18; hora++) {
      for (int minuto = 0; minuto < 60; minuto += 30) {
        final horaInicio = '${hora.toString().padLeft(2, '0')}:${minuto.toString().padLeft(2, '0')}';
        // Calcular hora fin (30 minutos después)
        int horaFinHora = hora;
        int horaFinMinuto = minuto + 30;
        if (horaFinMinuto >= 60) {
          horaFinHora++;
          horaFinMinuto -= 60;
        }
        if (horaFinHora <= 19) {
          final horaFin = '${horaFinHora.toString().padLeft(2, '0')}:${horaFinMinuto.toString().padLeft(2, '0')}';
          horarios.add('$horaInicio-$horaFin');
        }
      }
    }
    return horarios;
  }

  /// Genera lista de horarios de inicio (07:00 a 18:00) con intervalos de 30 minutos
  static List<String> generarHorariosInicio() {
    final horarios = <String>[];
    for (int hora = 7; hora <= 18; hora++) {
      horarios.add('${hora.toString().padLeft(2, '0')}:00');
      if (hora < 18) {
        horarios.add('${hora.toString().padLeft(2, '0')}:30');
      }
    }
    return horarios;
  }

  /// Genera lista de horarios de fin (08:00 a 19:00) con intervalos de 30 minutos
  static List<String> generarHorariosFin() {
    final horarios = <String>[];
    for (int hora = 8; hora <= 19; hora++) {
      horarios.add('${hora.toString().padLeft(2, '0')}:00');
      if (hora < 19) {
        horarios.add('${hora.toString().padLeft(2, '0')}:30');
      }
    }
    return horarios;
  }

  /// Calcula la disponibilidad de horarios verificando solapamientos
  static List<HorarioDisponibilidad> calcularDisponibilidad({
    required List<Walk> paseosExistentes,
    required DateTime fecha,
  }) {
    final horarios = generarHorarios();
    final disponibilidad = <HorarioDisponibilidad>[];

    // Normalizar la fecha para comparar solo día, mes y año
    final fechaComparar = DateTime(
      fecha.year,
      fecha.month,
      fecha.day,
    );

    // Filtrar solo los paseos programados para esta fecha
    final paseosDelDia = paseosExistentes.where((paseo) {
      final paseoFecha = DateTime(
        paseo.fechaPaseo.year,
        paseo.fechaPaseo.month,
        paseo.fechaPaseo.day,
      );
      return paseoFecha.isAtSameMomentAs(fechaComparar) &&
             paseo.estado == 'programado';
    }).toList();

    for (final horario in horarios) {
      final partes = horario.split('-');
      final horaInicio = partes[0];
      final horaFin = partes[1];

      // Convertir horas a minutos para facilitar la comparación
      final inicioMinutos = _horaAMinutos(horaInicio);
      final finMinutos = _horaAMinutos(horaFin);

      // Verificar si hay algún paseo que se solape con este horario
      final haySolapamiento = paseosDelDia.any((paseo) {
        if (paseo.horaInicio.isEmpty || paseo.horaFin == null) {
          return false;
        }

        final paseoInicioMinutos = _horaAMinutos(paseo.horaInicio);
        final paseoFinMinutos = _horaAMinutos(paseo.horaFin!);

        // Verificar solapamiento: dos intervalos se solapan si:
        // - El inicio del nuevo está dentro del intervalo existente, O
        // - El fin del nuevo está dentro del intervalo existente, O
        // - El nuevo intervalo contiene completamente al existente
        return (inicioMinutos < paseoFinMinutos && finMinutos > paseoInicioMinutos);
      });

      disponibilidad.add(HorarioDisponibilidad(
        horaInicio: horaInicio,
        horaFin: horaFin,
        disponible: !haySolapamiento,
        motivoBloqueo: haySolapamiento ? 'Horario ocupado' : null,
      ));
    }

    return disponibilidad;
  }

  /// Convierte una hora en formato "HH:mm" a minutos desde medianoche
  static int _horaAMinutos(String hora) {
    final partes = hora.split(':');
    final horas = int.parse(partes[0]);
    final minutos = int.parse(partes[1]);
    return horas * 60 + minutos;
  }

  /// Verifica si un horario específico está disponible
  static bool verificarDisponibilidadHorario({
    required List<Walk> paseosExistentes,
    required DateTime fecha,
    required String horaInicio,
    required String horaFin,
  }) {
    final fechaComparar = DateTime(
      fecha.year,
      fecha.month,
      fecha.day,
    );

    // Filtrar solo los paseos programados para esta fecha
    final paseosDelDia = paseosExistentes.where((paseo) {
      final paseoFecha = DateTime(
        paseo.fechaPaseo.year,
        paseo.fechaPaseo.month,
        paseo.fechaPaseo.day,
      );
      return paseoFecha.isAtSameMomentAs(fechaComparar) &&
             paseo.estado == 'programado';
    }).toList();

    final inicioMinutos = _horaAMinutos(horaInicio);
    final finMinutos = _horaAMinutos(horaFin);

    // Verificar si hay algún paseo que se solape
    final haySolapamiento = paseosDelDia.any((paseo) {
      if (paseo.horaInicio.isEmpty || paseo.horaFin == null) {
        return false;
      }

      final paseoInicioMinutos = _horaAMinutos(paseo.horaInicio);
      final paseoFinMinutos = _horaAMinutos(paseo.horaFin!);

      return (inicioMinutos < paseoFinMinutos && finMinutos > paseoInicioMinutos);
    });

    return !haySolapamiento;
  }
}
