class FirestorePaths {
  // Colección principal
  static const String paseadores = 'paseadores';
  
  // Subcolecciones
  static const String propietarios = 'propietarios';
  static const String caninos = 'caninos';
  static const String paseos = 'paseos';
  static const String notificaciones = 'notificaciones';
  
  // Subcolección de paseos_caninos (relación muchos a muchos)
  static const String paseosCaninos = 'paseos_caninos';
  
  // Helpers para construir paths de paseadores
  static String paseador(String paseadorId) => '$paseadores/$paseadorId';
  
  // Helpers para construir paths de propietarios
  static String propietariosPath(String paseadorId) => 
      '$paseadores/$paseadorId/$propietarios';
  
  static String propietario(String paseadorId, String propietarioId) => 
      '$paseadores/$paseadorId/$propietarios/$propietarioId';
  
  // Helpers para construir paths de caninos
  static String caninosPath(String paseadorId) => 
      '$paseadores/$paseadorId/$caninos';
  
  static String canino(String paseadorId, String caninoId) => 
      '$paseadores/$paseadorId/$caninos/$caninoId';
  
  // Helpers para construir paths de paseos
  static String paseosPath(String paseadorId) => 
      '$paseadores/$paseadorId/$paseos';
  
  static String paseo(String paseadorId, String paseoId) => 
      '$paseadores/$paseadorId/$paseos/$paseoId';
  
  // Helpers para construir paths de paseos_caninos (subcolección de paseos)
  static String paseosCaninosPath(String paseadorId, String paseoId) => 
      '$paseadores/$paseadorId/$paseos/$paseoId/$paseosCaninos';
  
  static String paseoCanino(String paseadorId, String paseoId, String paseoCaninoId) => 
      '$paseadores/$paseadorId/$paseos/$paseoId/$paseosCaninos/$paseoCaninoId';
  
  // Helpers para construir paths de notificaciones
  static String notificacionesPath(String paseadorId) => 
      '$paseadores/$paseadorId/$notificaciones';
  
  static String notificacion(String paseadorId, String notificacionId) => 
      '$paseadores/$paseadorId/$notificaciones/$notificacionId';
}
