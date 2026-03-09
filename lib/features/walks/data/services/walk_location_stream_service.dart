// =============================================================================
// WALK LOCATION STREAM SERVICE
// =============================================================================
// Expone un flujo de posiciones GPS con intervalo fijo (cada 15 s) para el
// paseo en curso. Usa un timer para no depender de intervalos por plataforma.
// =============================================================================

import 'dart:async';
import 'package:geolocator/geolocator.dart';

const Duration walkLocationInterval = Duration(seconds: 15);

/// Servicio que entrega la posición actual cada [walkLocationInterval].
/// La suscripción debe cancelarse al finalizar o pausar el paseo.
class WalkLocationStreamService {
  StreamSubscription<Position>? _subscription;

  /// Devuelve un stream que emite una posición cada 15 segundos.
  /// Obtiene la posición actual en cada tick (no depende del intervalo nativo del GPS).
  Stream<Position> getPositionStream() {
    return Stream.periodic(walkLocationInterval, (_) {}).asyncMap((_) async {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      return pos;
    });
  }

  /// Escucha el stream y ejecuta [onPosition] en cada posición.
  /// Devuelve la suscripción para poder cancelarla.
  StreamSubscription<Position> listen(void Function(Position) onPosition, {Function(dynamic)? onError}) {
    _subscription?.cancel();
    _subscription = getPositionStream().listen(onPosition, onError: onError);
    return _subscription!;
  }

  void cancel() {
    _subscription?.cancel();
    _subscription = null;
  }
}
