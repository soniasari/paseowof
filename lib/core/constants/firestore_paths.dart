class FirestorePaths {
  // Colección raíz en Firestore
  static const String paseadores = 'paseadores';
  
  // Nombres de subcolecciones
  static const String propietarios = 'propietarios';
  static const String caninos = 'caninos';
  static const String paseos = 'paseos';
  static const String notificaciones = 'notificaciones';
  static const String paseosCaninos = 'paseos_caninos';
  
  static String paseador(String paseadorId) => '$paseadores/$paseadorId';
  
  static String propietariosPath(String paseadorId) => 
      '$paseadores/$paseadorId/$propietarios';
  
  static String propietario(String paseadorId, String propietarioId) => 
      '$paseadores/$paseadorId/$propietarios/$propietarioId';
  
  static String caninosPath(String paseadorId) => 
      '$paseadores/$paseadorId/$caninos';
  
  static String canino(String paseadorId, String caninoId) => 
      '$paseadores/$paseadorId/$caninos/$caninoId';
  
  static String paseosPath(String paseadorId) => 
      '$paseadores/$paseadorId/$paseos';
  
  static String paseo(String paseadorId, String paseoId) => 
      '$paseadores/$paseadorId/$paseos/$paseoId';
  
  static String paseosCaninosPath(String paseadorId, String paseoId) => 
      '$paseadores/$paseadorId/$paseos/$paseoId/$paseosCaninos';
  
  static String paseoCanino(String paseadorId, String paseoId, String paseoCaninoId) => 
      '$paseadores/$paseadorId/$paseos/$paseoId/$paseosCaninos/$paseoCaninoId';
  
  static String notificacionesPath(String paseadorId) => 
      '$paseadores/$paseadorId/$notificaciones';
  
  static String notificacion(String paseadorId, String notificacionId) => 
      '$paseadores/$paseadorId/$notificaciones/$notificacionId';
}
