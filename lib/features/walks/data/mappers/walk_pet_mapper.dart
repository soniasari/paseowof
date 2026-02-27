import '../../domain/entities/walk_pet.dart';

class WalkPetMapper {
  // Convertir entidad a Map para Firestore
  static Map<String, dynamic> toMap(WalkPet walkPet) {
    return {
      'paseoId': walkPet.paseoId,
      'caninoId': walkPet.caninoId,
      'nombreCanino': walkPet.nombreCanino,
    };
  }

  // Convertir Map de Firestore a entidad
  static WalkPet fromMap(String id, Map<String, dynamic> map) {
    return WalkPet(
      id: id,
      paseoId: map['paseoId'] ?? '',
      caninoId: map['caninoId'] ?? '',
      nombreCanino: map['nombreCanino'] ?? '',
    );
  }
}

