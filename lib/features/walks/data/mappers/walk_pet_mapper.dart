import '../../domain/entities/walk_pet.dart';

class WalkPetMapper {
  // Pasamos la entidad a mapa para guardar en Firestore
  static Map<String, dynamic> toMap(WalkPet walkPet) {
    return {
      'paseoId': walkPet.paseoId,
      'caninoId': walkPet.caninoId,
      'nombreCanino': walkPet.nombreCanino,
    };
  }

  // Leemos el mapa de Firestore y armamos la entidad WalkPet
  static WalkPet fromMap(String id, Map<String, dynamic> map) {
    return WalkPet(
      id: id,
      paseoId: map['paseoId'] ?? '',
      caninoId: map['caninoId'] ?? '',
      nombreCanino: map['nombreCanino'] ?? '',
    );
  }
}

