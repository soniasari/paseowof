import '../../domain/entities/pet.dart';

class PetMapper {
  static Map<String, dynamic> toMap(Pet pet) {
    return {
      'paseadorId': pet.paseadorId,
      'propietarioId': pet.propietarioId,
      'nombreMascota': pet.nombre,
      'raza': pet.raza,
      'edad': pet.edad,
      'tamano': pet.tamano,
      'nivelEnergia': pet.nivelEnergia,
      'observaciones': pet.observaciones,
      'peso': pet.peso,
      'color': pet.color,
      'foto': pet.foto,
      'fechaRegistro': pet.fechaRegistro.toIso8601String(),
      'activo': pet.activo,
    };
  }

  static Pet fromMap(String id, Map<String, dynamic> map) {
    return Pet(
      id: id,
      paseadorId: map['paseadorId'] ?? '',
      propietarioId: map['propietarioId'] ?? '',
      nombre: map['nombreMascota'] ?? map['nombre'] ?? '',
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
}
