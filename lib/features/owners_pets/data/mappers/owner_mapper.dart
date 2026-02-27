import '../../domain/entities/owner.dart';

class OwnerMapper {
  static Map<String, dynamic> toMap(Owner owner) {
    return {
      'paseadorId': owner.paseadorId,
      'nombre': owner.nombre,
      'ci': owner.ci,
      'telefono': owner.telefono,
      'direccion': owner.direccion,
      'email': owner.email,
      'fechaRegistro': owner.fechaRegistro.toIso8601String(),
      'activo': owner.activo,
    };
  }

  static Owner fromMap(String id, Map<String, dynamic> map) {
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
}
