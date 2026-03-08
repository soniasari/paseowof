// =============================================================================
// SCHEDULE AVAILABILITY SERVICE
// =============================================================================
// Calcula qué franjas del día están libres u ocupadas según los paseos ya
// programados. Si un paseo está en 21:30–22:00, ese horario no debe ofrecerse
// al programar otro paseo el mismo día. Este servicio no depende de Riverpod.
// =============================================================================

import 'package:paseowof/features/walks/domain/entities/walk.dart';

/// Resultado por cada horario: hora inicio, hora fin, si está libre y motivo si está ocupada.
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

/// Servicio de disponibilidad: franjas 07:00–23:00, solapamiento con paseos y 30 min de margen para traslado.
class ScheduleAvailabilityService {
  /// Minutos de margen entre el fin de un paseo y el inicio del siguiente (traslado del paseador).
  static const int minutosMargenTraslado = 30;

  /// Todas las franjas del día (inicio–fin cada 30 min). Última: 22:30–23:00.
  static List<String> generarHorarios() {
    final horarios = <String>[];
    for (int hora = 7; hora <= 22; hora++) {
      for (int minuto = 0; minuto < 60; minuto += 30) {
        final horaInicio = '${hora.toString().padLeft(2, '0')}:${minuto.toString().padLeft(2, '0')}';
        int horaFinHora = hora;
        int horaFinMinuto = minuto + 30;
        if (horaFinMinuto >= 60) {
          horaFinHora++;
          horaFinMinuto -= 60;
        }
        if (horaFinHora <= 23) {
          final horaFin = '${horaFinHora.toString().padLeft(2, '0')}:${horaFinMinuto.toString().padLeft(2, '0')}';
          horarios.add('$horaInicio-$horaFin');
        }
      }
    }
    return horarios;
  }

  /// Lista de horas de inicio (07:00 a 22:30, cada 30 min).
  static List<String> generarHorariosInicio() {
    final horarios = <String>[];
    for (int hora = 7; hora <= 22; hora++) {
      horarios.add('${hora.toString().padLeft(2, '0')}:00');
      if (hora < 22) {
        horarios.add('${hora.toString().padLeft(2, '0')}:30');
      } else {
        horarios.add('22:30');
      }
    }
    return horarios;
  }

  /// Lista de horas de fin (08:00 a 23:00, cada 30 min).
  static List<String> generarHorariosFin() {
    final horarios = <String>[];
    for (int hora = 8; hora <= 23; hora++) {
      horarios.add('${hora.toString().padLeft(2, '0')}:00');
      if (hora < 23) {
        horarios.add('${hora.toString().padLeft(2, '0')}:30');
      }
    }
    return horarios;
  }

  /// Convierte "HH:mm" a minutos desde medianoche (para filtrar horarios pasados).
  static int horaAMinutos(String hora) => _horaAMinutos(hora);

  /// Marca cada franja como libre u ocupada según los paseos existentes.
  /// Se bloquea si se solapa con un paseo o si el inicio cae dentro del margen de traslado
  /// (ventana [finPaseo, finPaseo+30 min)); ej. paseo 18:00–19:00 bloquea 19:00–19:30, el siguiente libre es 19:30.
  static List<HorarioDisponibilidad> calcularDisponibilidad({
    required List<Walk> paseosExistentes,
    required DateTime fecha,
  }) {
    final horarios = generarHorarios();
    final disponibilidad = <HorarioDisponibilidad>[];

    final fYear = fecha.year;
    final fMonth = fecha.month;
    final fDay = fecha.day;

    final paseosDelDia = paseosExistentes.where((paseo) {
      return paseo.fechaPaseo.year == fYear &&
             paseo.fechaPaseo.month == fMonth &&
             paseo.fechaPaseo.day == fDay &&
             paseo.estado == 'programado';
    }).toList();

    for (final horario in horarios) {
      final partes = horario.split('-');
      final horaInicio = partes[0];
      final horaFin = partes[1];

      final inicioMinutos = _horaAMinutos(horaInicio);
      final finMinutos = _horaAMinutos(horaFin);

      // Bloqueado si se solapa con algún paseo o si el inicio cae DENTRO del margen de traslado (30 min) tras el fin del paseo.
      // Margen correcto: solo bloquear inicios en [finPaseo, finPaseo+30), no todo lo anterior a finPaseo+30.
      final bloqueado = paseosDelDia.any((paseo) {
        if (paseo.horaInicio.isEmpty || paseo.horaFin == null) return false;
        final paseoInicioMinutos = _horaAMinutos(paseo.horaInicio);
        final paseoFinMinutos = _horaAMinutos(paseo.horaFin!);
        final solapamiento = inicioMinutos < paseoFinMinutos && finMinutos > paseoInicioMinutos;
        final dentroMargenTraslado = inicioMinutos >= paseoFinMinutos &&
            inicioMinutos < paseoFinMinutos + minutosMargenTraslado;
        return solapamiento || dentroMargenTraslado;
      });

      disponibilidad.add(HorarioDisponibilidad(
        horaInicio: horaInicio,
        horaFin: horaFin,
        disponible: !bloqueado,
        motivoBloqueo: bloqueado ? 'Horario ocupado' : null,
      ));
    }

    return disponibilidad;
  }

  /// Pasa "HH:mm" a minutos desde medianoche (para comparar)
  static int _horaAMinutos(String hora) {
    final partes = hora.split(':');
    final horas = int.parse(partes[0]);
    final minutos = int.parse(partes[1]);
    return horas * 60 + minutos;
  }

  /// Comprueba si la franja [horaInicio]–[horaFin] está libre: sin solapamiento
  /// y sin iniciar antes de 30 min después del fin de ningún paseo (margen de traslado).
  static bool verificarDisponibilidadHorario({
    required List<Walk> paseosExistentes,
    required DateTime fecha,
    required String horaInicio,
    required String horaFin,
  }) {
    final fYear = fecha.year;
    final fMonth = fecha.month;
    final fDay = fecha.day;

    final paseosDelDia = paseosExistentes.where((paseo) {
      return paseo.fechaPaseo.year == fYear &&
             paseo.fechaPaseo.month == fMonth &&
             paseo.fechaPaseo.day == fDay &&
             paseo.estado == 'programado';
    }).toList();

    final inicioMinutos = _horaAMinutos(horaInicio);
    final finMinutos = _horaAMinutos(horaFin);

    final bloqueado = paseosDelDia.any((paseo) {
      if (paseo.horaInicio.isEmpty || paseo.horaFin == null) return false;
      final paseoInicioMinutos = _horaAMinutos(paseo.horaInicio);
      final paseoFinMinutos = _horaAMinutos(paseo.horaFin!);
      final solapamiento = inicioMinutos < paseoFinMinutos && finMinutos > paseoInicioMinutos;
      final dentroMargenTraslado = inicioMinutos >= paseoFinMinutos &&
          inicioMinutos < paseoFinMinutos + minutosMargenTraslado;
      return solapamiento || dentroMargenTraslado;
    });

    return !bloqueado;
  }
}
