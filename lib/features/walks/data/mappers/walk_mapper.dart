import '../../domain/entities/walk.dart';

class WalkMapper {
  // Convertir entidad a Map para Firestore
  static Map<String, dynamic> toMap(Walk walk) {
    return {
      'paseadorId': walk.paseadorId,
      'propietarioId': walk.propietarioId,
      'fechaPaseo': walk.fechaPaseo.toIso8601String(),
      'horaInicio': walk.horaInicio,
      'horaFin': walk.horaFin,
      'duracionMinutos': walk.duracionMinutos,
      'estado': walk.estado,
      'direccionRecogida': walk.direccionRecogida,
      'observaciones': walk.observaciones,
      'notificacionEnviada': walk.notificacionEnviada,
      'fechaCreacion': walk.fechaCreacion.toIso8601String(),
      'fechaModificacion': walk.fechaModificacion.toIso8601String(),
      'motivoCancelacion': walk.motivoCancelacion,
    };
  }

  // Convertir Map de Firestore a entidad
  static Walk fromMap(String id, Map<String, dynamic> map) {
    return Walk(
      id: id,
      paseadorId: map['paseadorId'] ?? '',
      propietarioId: map['propietarioId'] ?? '',
      fechaPaseo: map['fechaPaseo'] != null
          ? DateTime.parse(map['fechaPaseo'])
          : DateTime.now(),
      horaInicio: map['horaInicio'] ?? '',
      horaFin: map['horaFin'],
      duracionMinutos: map['duracionMinutos'],
      estado: map['estado'] ?? 'programado',
      direccionRecogida: map['direccionRecogida'],
      observaciones: map['observaciones'],
      notificacionEnviada: map['notificacionEnviada'] ?? false,
      fechaCreacion: map['fechaCreacion'] != null
          ? DateTime.parse(map['fechaCreacion'])
          : DateTime.now(),
      fechaModificacion: map['fechaModificacion'] != null
          ? DateTime.parse(map['fechaModificacion'])
          : DateTime.now(),
      motivoCancelacion: map['motivoCancelacion'],
    );
  }
}
