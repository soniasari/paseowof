class Walk {
  final String id; // paseo_id
  final String paseadorId; // paseador_id - referencia al paseador
  final String propietarioId; // propietario_id - referencia al propietario
  final DateTime fechaPaseo; // fecha_paseo
  final String horaInicio; // hora_inicio en formato "HH:mm"
  final String? horaFin; // hora_fin en formato "HH:mm"
  final int? duracionMinutos; // duracion_minutos
  final String estado; // 'programado', 'completado', 'cancelado', 'reprogramado'
  final String? direccionRecogida;
  final String? observaciones;
  final double? precio; // precio del paseo
  final bool notificacionEnviada; // notificacion_enviada
  final DateTime fechaCreacion; // fecha_creacion
  final DateTime fechaModificacion; // fecha_modificacion
  final String? motivoCancelacion;

  Walk({
    required this.id,
    required this.paseadorId,
    required this.propietarioId,
    required this.fechaPaseo,
    required this.horaInicio,
    this.horaFin,
    this.duracionMinutos,
    this.estado = 'programado',
    this.direccionRecogida,
    this.observaciones,
    this.precio,
    this.notificacionEnviada = false,
    required this.fechaCreacion,
    required this.fechaModificacion,
    this.motivoCancelacion,
  });

  Map<String, dynamic> toMap() {
    return {
      'paseadorId': paseadorId,
      'propietarioId': propietarioId,
      'fechaPaseo': fechaPaseo.toIso8601String(),
      'horaInicio': horaInicio,
      'horaFin': horaFin,
      'duracionMinutos': duracionMinutos,
      'estado': estado,
      'direccionRecogida': direccionRecogida,
      'observaciones': observaciones,
      'precio': precio,
      'notificacionEnviada': notificacionEnviada,
      'fechaCreacion': fechaCreacion.toIso8601String(),
      'fechaModificacion': fechaModificacion.toIso8601String(),
      'motivoCancelacion': motivoCancelacion,
    };
  }

  factory Walk.fromMap(String id, Map<String, dynamic> map) {
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
      precio: map['precio'] != null ? (map['precio'] as num).toDouble() : null,
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

  Walk copyWith({
    DateTime? fechaPaseo,
    String? horaInicio,
    String? horaFin,
    int? duracionMinutos,
    String? estado,
    String? direccionRecogida,
    String? observaciones,
    double? precio,
    bool? notificacionEnviada,
    DateTime? fechaModificacion,
    String? motivoCancelacion,
  }) {
    return Walk(
      id: id,
      paseadorId: paseadorId,
      propietarioId: propietarioId,
      fechaPaseo: fechaPaseo ?? this.fechaPaseo,
      horaInicio: horaInicio ?? this.horaInicio,
      horaFin: horaFin ?? this.horaFin,
      duracionMinutos: duracionMinutos ?? this.duracionMinutos,
      estado: estado ?? this.estado,
      direccionRecogida: direccionRecogida ?? this.direccionRecogida,
      observaciones: observaciones ?? this.observaciones,
      precio: precio ?? this.precio,
      notificacionEnviada: notificacionEnviada ?? this.notificacionEnviada,
      fechaCreacion: fechaCreacion,
      fechaModificacion: fechaModificacion ?? this.fechaModificacion,
      motivoCancelacion: motivoCancelacion ?? this.motivoCancelacion,
    );
  }
}
