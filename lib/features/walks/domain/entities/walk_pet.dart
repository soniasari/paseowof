/// Relación paseo–canino: qué canino va en cada paseo (paseos_caninos en Firestore)
class WalkPet {
  final String id; // paseo_canino_id
  final String paseoId; // paseo_id - referencia al paseo
  final String caninoId; // canino_id - referencia al canino
  final String nombreCanino; // nombre_canino - para facilitar consultas

  WalkPet({
    required this.id,
    required this.paseoId,
    required this.caninoId,
    required this.nombreCanino,
  });

  Map<String, dynamic> toMap() {
    return {
      'paseoId': paseoId,
      'caninoId': caninoId,
      'nombreCanino': nombreCanino,
    };
  }

  factory WalkPet.fromMap(String id, Map<String, dynamic> map) {
    return WalkPet(
      id: id,
      paseoId: map['paseoId'] ?? '',
      caninoId: map['caninoId'] ?? '',
      nombreCanino: map['nombreCanino'] ?? '',
    );
  }

  WalkPet copyWith({
    String? paseoId,
    String? caninoId,
    String? nombreCanino,
  }) {
    return WalkPet(
      id: id,
      paseoId: paseoId ?? this.paseoId,
      caninoId: caninoId ?? this.caninoId,
      nombreCanino: nombreCanino ?? this.nombreCanino,
    );
  }
}

