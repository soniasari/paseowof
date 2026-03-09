class FirestorePaths {
  // Colección raíz en Firestore
  static const String paseadores = 'paseadores';
  
  // Nombres de subcolecciones
  static const String propietarios = 'propietarios';
  static const String caninos = 'caninos';
  static const String paseos = 'paseos';
  static const String notificaciones = 'notificaciones';
  static const String paseosCaninos = 'paseos_caninos';
  /// Subcolección de puntos GPS del paseo (15 puntos al finalizar).
  static const String gpsPointsWalk = 'gps_points_walk';

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

  /// Ruta de la subcolección de puntos GPS de un paseo (15 puntos al finalizar).
  static String gpsPointsWalkPath(String paseadorId, String paseoId) =>
      '${paseo(paseadorId, paseoId)}/$gpsPointsWalk';

  /// Documento que guarda la ruta (15 puntos) y metadatos del paseo.
  static String gpsPointsWalkDoc(String paseadorId, String paseoId) =>
      '${gpsPointsWalkPath(paseadorId, paseoId)}/track';

  static String notificacionesPath(String paseadorId) =>
      '$paseadores/$paseadorId/$notificaciones';
  
  static String notificacion(String paseadorId, String notificacionId) => 
      '$paseadores/$paseadorId/$notificaciones/$notificacionId';
}
