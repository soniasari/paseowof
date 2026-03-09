// =============================================================================
// LOCATION PERMISSION SERVICE
// =============================================================================
// Comprueba y solicita permiso de ubicación y que el servicio GPS esté activo
// antes de iniciar un paseo. La UI usa este servicio al pulsar "Iniciar paseo".
// =============================================================================

import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

enum LocationCheckResult {
  ok,
  serviceDisabled,
  permissionDenied,
  permissionPermanentlyDenied,
}

class LocationPermissionService {
  /// Indica si el servicio de ubicación del dispositivo está habilitado.
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Comprueba el estado del permiso de ubicación (no solicita).
  Future<PermissionStatus> getLocationPermissionStatus() async {
    final status = await Permission.locationWhenInUse.status;
    return status;
  }

  /// Comprueba si podemos usar la ubicación: servicio activo y permiso concedido.
  /// Si no, devuelve el motivo para mostrar en la UI (activar GPS o conceder permiso).
  Future<LocationCheckResult> checkCanTrackLocation() async {
    final enabled = await isLocationServiceEnabled();
    if (!enabled) return LocationCheckResult.serviceDisabled;

    final status = await getLocationPermissionStatus();
    if (status.isGranted) return LocationCheckResult.ok;
    if (status.isPermanentlyDenied) return LocationCheckResult.permissionPermanentlyDenied;
    if (status.isDenied) return LocationCheckResult.permissionDenied;

    return LocationCheckResult.permissionDenied;
  }

  /// Solicita el permiso de ubicación. Debe llamarse cuando el usuario
  /// intenta iniciar el paseo y el permiso no está concedido.
  Future<LocationCheckResult> requestLocationPermission() async {
    final enabled = await isLocationServiceEnabled();
    if (!enabled) return LocationCheckResult.serviceDisabled;

    final status = await Permission.locationWhenInUse.request();
    if (status.isGranted) return LocationCheckResult.ok;
    if (status.isPermanentlyDenied) return LocationCheckResult.permissionPermanentlyDenied;

    return LocationCheckResult.permissionDenied;
  }

  /// Abre la configuración de la app para que el usuario pueda activar
  /// ubicación o conceder permiso manualmente.
  Future<bool> openSystemAppSettings() async {
    return await openAppSettings();
  }
}
