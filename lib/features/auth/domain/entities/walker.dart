class Walker {
  final String id; // paseador_id - UID del usuario autenticado
  final String nombre;
  final String ci; // Formato: "1234567 LP" - Carnet de Identidad OBLIGATORIO
  final String email;
  final String? telefono;
  final DateTime fechaRegistro; // fecha_registro
  final bool activo;
  final DateTime? ultimoAcceso;

  Walker({
    required this.id,
    required this.nombre,
    required this.ci,
    required this.email,
    this.telefono,
    required this.fechaRegistro,
    this.activo = true,
    this.ultimoAcceso,
  });

  // Método para convertir a Map (para Firestore)
  Map<String, dynamic> toMap() {
    return {
      'nombre': nombre,
      'ci': ci,
      'email': email,
      'telefono': telefono,
      'fechaRegistro': fechaRegistro.toIso8601String(),
      'activo': activo,
      'ultimoAcceso': ultimoAcceso?.toIso8601String(),
    };
  }

  // Método para crear desde Map (desde Firestore)
  factory Walker.fromMap(String id, Map<String, dynamic> map) {
    return Walker(
      id: id,
      nombre: map['nombre'] ?? '',
      ci: map['ci'] ?? '',
      email: map['email'] ?? '',
      telefono: map['telefono'],
      fechaRegistro: map['fechaRegistro'] != null
          ? DateTime.parse(map['fechaRegistro'])
          : DateTime.now(),
      activo: map['activo'] ?? true,
      ultimoAcceso: map['ultimoAcceso'] != null
          ? DateTime.parse(map['ultimoAcceso'])
          : null,
    );
  }

  // Copiar con cambios
  Walker copyWith({
    String? nombre,
    String? ci,
    String? email,
    String? telefono,
    bool? activo,
    DateTime? ultimoAcceso,
  }) {
    return Walker(
      id: id,
      nombre: nombre ?? this.nombre,
      ci: ci ?? this.ci,
      email: email ?? this.email,
      telefono: telefono ?? this.telefono,
      fechaRegistro: fechaRegistro,
      activo: activo ?? this.activo,
      ultimoAcceso: ultimoAcceso ?? this.ultimoAcceso,
    );
  }
}
