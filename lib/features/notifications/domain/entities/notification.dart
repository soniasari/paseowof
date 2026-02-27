class Notification {
  final String id; // notificacion_id
  final String paseadorId; // paseador_id - referencia al paseador
  final String? paseoId; // paseo_id - referencia al paseo (opcional)
  final DateTime fechaProgramada; // fecha_programada
  final String tipo; // tipo - default: 'recordatorio_paseo'
  final bool enviada; // enviada - default: false
  final bool leida; // leida - default: false
  final String titulo; // titulo - OBLIGATORIO
  final String? mensaje; // mensaje

  Notification({
    required this.id,
    required this.paseadorId,
    this.paseoId,
    required this.fechaProgramada,
    this.tipo = 'recordatorio_paseo',
    this.enviada = false,
    this.leida = false,
    required this.titulo,
    this.mensaje,
  });

  Map<String, dynamic> toMap() {
    return {
      'paseadorId': paseadorId,
      'paseoId': paseoId,
      'fechaProgramada': fechaProgramada.toIso8601String(),
      'tipo': tipo,
      'enviada': enviada,
      'leida': leida,
      'titulo': titulo,
      'mensaje': mensaje,
    };
  }

  factory Notification.fromMap(String id, Map<String, dynamic> map) {
    return Notification(
      id: id,
      paseadorId: map['paseadorId'] ?? '',
      paseoId: map['paseoId'],
      fechaProgramada: map['fechaProgramada'] != null
          ? DateTime.parse(map['fechaProgramada'])
          : DateTime.now(),
      tipo: map['tipo'] ?? 'recordatorio_paseo',
      enviada: map['enviada'] ?? false,
      leida: map['leida'] ?? false,
      titulo: map['titulo'] ?? '',
      mensaje: map['mensaje'],
    );
  }

  Notification copyWith({
    String? paseoId,
    DateTime? fechaProgramada,
    String? tipo,
    bool? enviada,
    bool? leida,
    String? titulo,
    String? mensaje,
  }) {
    return Notification(
      id: id,
      paseadorId: paseadorId,
      paseoId: paseoId ?? this.paseoId,
      fechaProgramada: fechaProgramada ?? this.fechaProgramada,
      tipo: tipo ?? this.tipo,
      enviada: enviada ?? this.enviada,
      leida: leida ?? this.leida,
      titulo: titulo ?? this.titulo,
      mensaje: mensaje ?? this.mensaje,
    );
  }
}

