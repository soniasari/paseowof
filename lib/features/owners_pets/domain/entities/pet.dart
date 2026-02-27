class Pet {
  final String id; // canino_id
  final String paseadorId; // paseador_id - referencia al paseador
  final String propietarioId; // propietario_id - referencia al propietario
  final String nombre;
  final String? raza;
  final int? edad; // En años
  final String? tamano; // 'pequeño', 'mediano', 'grande'
  final String? nivelEnergia; // 'bajo', 'medio', 'alto'
  final String? observaciones;
  final double? peso; // En kg
  final String? color;
  final String? foto; // URL de la imagen en Firebase Storage
  final DateTime fechaRegistro; // fecha_registro
  final bool activo;

  Pet({
    required this.id,
    required this.paseadorId,
    required this.propietarioId,
    required this.nombre,
    this.raza,
    this.edad,
    this.tamano,
    this.nivelEnergia,
    this.observaciones,
    this.peso,
    this.color,
    this.foto,
    required this.fechaRegistro,
    this.activo = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'paseadorId': paseadorId,
      'propietarioId': propietarioId,
      'nombre': nombre,
      'raza': raza,
      'edad': edad,
      'tamano': tamano,
      'nivelEnergia': nivelEnergia,
      'observaciones': observaciones,
      'peso': peso,
      'color': color,
      'foto': foto,
      'fechaRegistro': fechaRegistro.toIso8601String(),
      'activo': activo,
    };
  }

  factory Pet.fromMap(String id, Map<String, dynamic> map) {
    return Pet(
      id: id,
      paseadorId: map['paseadorId'] ?? '',
      propietarioId: map['propietarioId'] ?? '',
      nombre: map['nombre'] ?? '',
      raza: map['raza'],
      edad: map['edad'],
      tamano: map['tamano'],
      nivelEnergia: map['nivelEnergia'],
      observaciones: map['observaciones'],
      peso: map['peso'] != null ? (map['peso'] as num).toDouble() : null,
      color: map['color'],
      foto: map['foto'],
      fechaRegistro: map['fechaRegistro'] != null
          ? DateTime.parse(map['fechaRegistro'])
          : DateTime.now(),
      activo: map['activo'] ?? true,
    );
  }

  Pet copyWith({
    String? nombre,
    String? raza,
    int? edad,
    String? tamano,
    String? nivelEnergia,
    String? observaciones,
    double? peso,
    String? color,
    String? foto,
    bool? activo,
  }) {
    return Pet(
      id: id,
      paseadorId: paseadorId,
      propietarioId: propietarioId,
      nombre: nombre ?? this.nombre,
      raza: raza ?? this.raza,
      edad: edad ?? this.edad,
      tamano: tamano ?? this.tamano,
      nivelEnergia: nivelEnergia ?? this.nivelEnergia,
      observaciones: observaciones ?? this.observaciones,
      peso: peso ?? this.peso,
      color: color ?? this.color,
      foto: foto ?? this.foto,
      fechaRegistro: fechaRegistro,
      activo: activo ?? this.activo,
    );
  }
}
