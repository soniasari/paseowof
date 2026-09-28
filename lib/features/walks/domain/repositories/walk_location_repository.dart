import '../entities/location_fix.dart';

/// Fuente de ubicaciones del paseo en curso.
///
/// Mientras las actualizaciones están activas, la implementación debe mantener
/// el GPS funcionando con la pantalla apagada o la app en segundo plano
/// (en Android, con una notificación fija de servicio en primer plano).
abstract class WalkLocationRepository {
  /// Empieza a entregar lecturas. Reemplaza cualquier suscripción anterior.
  Future<void> startUpdates({
    required void Function(LocationFix fix) onFix,
    void Function(Object error)? onError,
  });

  /// Vuelve a suscribirse con otro proveedor de ubicación del sistema; sirve
  /// cuando el flujo quedó mudo sin dar error. Solo debe llamarse con la app
  /// en primer plano.
  Future<void> restartUpdates({
    required void Function(LocationFix fix) onFix,
    void Function(Object error)? onError,
  });

  /// Detiene las lecturas y el servicio en segundo plano.
  Future<void> stopUpdates();

  /// Lectura puntual con tiempo límite; null si no llega a tiempo.
  Future<LocationFix?> getCurrentFix();

  /// Última lectura conocida por el sistema, si la hay.
  Future<LocationFix?> getLastKnownFix();

  /// Nombre corto del proveedor activo (solo para diagnóstico).
  String get providerLabel;
}
