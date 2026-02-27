import '../../domain/entities/walker.dart';

class WalkerMapper {
  // Convertir entidad a Map para Firestore
  static Map<String, dynamic> toMap(Walker walker) {
    return {
      'nombre': walker.nombre,
      'ci': walker.ci,
      'email': walker.email,
      'telefono': walker.telefono,
      'fechaRegistro': walker.fechaRegistro.toIso8601String(),
      'activo': walker.activo,
      'ultimoAcceso': walker.ultimoAcceso?.toIso8601String(),
    };
  }

  // Convertir Map de Firestore a entidad
  static Walker fromMap(String id, Map<String, dynamic> map) {
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
}
