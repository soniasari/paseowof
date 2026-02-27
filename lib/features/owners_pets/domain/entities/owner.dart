class Owner {
  final String id; // propietario_id
  final String paseadorId; // paseador_id - referencia al paseador
  final String nombre;
  final String ci; // Formato: "7654321 LP" - Carnet de Identidad OBLIGATORIO
  final String? telefono;
  final String? direccion;
  final String? email;
  final DateTime fechaRegistro; // fecha_registro
  final bool activo;

  Owner({
    required this.id,
    required this.paseadorId,
    required this.nombre,
    required this.ci,
    this.telefono,
    this.direccion,
    this.email,
    required this.fechaRegistro,
    this.activo = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'paseadorId': paseadorId,
      'nombre': nombre,
      'ci': ci,
      'telefono': telefono,
      'direccion': direccion,
      'email': email,
      'fechaRegistro': fechaRegistro.toIso8601String(),
      'activo': activo,
    };
  }

  factory Owner.fromMap(String id, Map<String, dynamic> map) {
    return Owner(
      id: id,
      paseadorId: map['paseadorId'] ?? '',
      nombre: map['nombre'] ?? '',
      ci: map['ci'] ?? '',
      telefono: map['telefono'],
      direccion: map['direccion'],
      email: map['email'],
      fechaRegistro: map['fechaRegistro'] != null
          ? DateTime.parse(map['fechaRegistro'])
          : DateTime.now(),
      activo: map['activo'] ?? true,
    );
  }

  Owner copyWith({
    String? nombre,
    String? ci,
    String? telefono,
    String? direccion,
    String? email,
    bool? activo,
  }) {
    return Owner(
      id: id,
      paseadorId: paseadorId,
      nombre: nombre ?? this.nombre,
      ci: ci ?? this.ci,
      telefono: telefono ?? this.telefono,
      direccion: direccion ?? this.direccion,
      email: email ?? this.email,
      fechaRegistro: fechaRegistro,
      activo: activo ?? this.activo,
    );
  }
}
