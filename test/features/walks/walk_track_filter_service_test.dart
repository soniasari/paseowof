import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:paseowof/features/walks/data/services/walk_track_filter_service.dart';

void main() {
  late WalkTrackFilterService filter;

  setUp(() {
    filter = WalkTrackFilterService();
  });

  test('un corte de señal largo (>5 min) no bloquea el tracking futuro', () {
    final t0 = DateTime.now().subtract(const Duration(minutes: 20));

    final first = filter.processPoint(
      latitude: 4.65300,
      longitude: -74.05500,
      timestamp: t0,
      accuracyMeters: 8,
    );
    final second = filter.processPoint(
      latitude: 4.65305,
      longitude: -74.05500,
      timestamp: t0.add(const Duration(seconds: 10)),
      accuracyMeters: 8,
    );
    expect(first.accepted, isTrue);
    expect(second.accepted, isTrue);
    final distanceBeforeGap = filter.totalDistanceKm;
    expect(distanceBeforeGap, greaterThan(0));

    // Salto espacial grande tras >5 min: no debe rechazarse como outlier eterno.
    final afterGap = filter.processPoint(
      latitude: 4.67000,
      longitude: -74.05500,
      timestamp: t0.add(const Duration(minutes: 6)),
      accuracyMeters: 8,
    );
    expect(afterGap.accepted, isTrue);
    expect(
      afterGap.totalDistanceKm,
      closeTo(distanceBeforeGap, 0.0001),
      reason: 'el salto del hueco no debe sumar distancia',
    );

    final resumed = filter.processPoint(
      latitude: 4.67005,
      longitude: -74.05500,
      timestamp: t0.add(const Duration(minutes: 6, seconds: 10)),
      accuracyMeters: 8,
    );
    expect(resumed.accepted, isTrue);
    expect(
      resumed.totalDistanceKm,
      greaterThan(distanceBeforeGap),
      reason: 'tras el hueco el tracking debe volver a acumular',
    );
  });

  test('acumula distancia en un recorrido caminando de al menos 10 puntos', () {
    // Recorrido ~hacia el norte en Bogotá, ~1.1 m/s, un punto cada 5 s (~5.5 m).
    const startLat = 4.653000;
    const startLng = -74.055000;
    const dLat = 0.0000495; // ~5.5 m
    final t0 = DateTime.now().subtract(const Duration(minutes: 15));

    FilterResult? last;
    for (var i = 0; i < 12; i++) {
      last = filter.processPoint(
        latitude: startLat + dLat * i,
        longitude: startLng,
        timestamp: t0.add(Duration(seconds: 5 * i)),
        accuracyMeters: 10,
      );
      expect(last.accepted, isTrue, reason: 'punto $i debería aceptarse');
    }

    // 11 tramos × ~5.5 m ≈ 60 m. Kalman reduce un poco el primer tramo.
    expect(filter.smoothedPoints.length, 12);
    expect(filter.totalDistanceKm, greaterThan(0.04));
    expect(filter.totalDistanceKm, lessThan(0.12));
    expect(last!.totalDistanceKm, filter.totalDistanceKm);
  });

  test('paseo real de ~250 m (ruta La Paz, Av. Busch) mide cerca del valor esperado', () {
    // Tramo aproximado C. Rep. de Cuba 1735 → Av. Busch 1590 (La Paz, Bolivia),
    // interpolado en línea recta con un fix cada 5 s a ~1.35 m/s.
    const startLat = -16.4999, startLng = -68.1201;
    const endLat = -16.4980, endLng = -68.1212;
    final expectedMeters = Geolocator.distanceBetween(startLat, startLng, endLat, endLng);
    final steps = (expectedMeters / (1.35 * 5)).round();
    final t0 = DateTime.now().subtract(const Duration(minutes: 10));

    for (var i = 0; i <= steps; i++) {
      final f = i / steps;
      final r = filter.processPoint(
        latitude: startLat + (endLat - startLat) * f,
        longitude: startLng + (endLng - startLng) * f,
        timestamp: t0.add(Duration(seconds: 5 * i)),
        accuracyMeters: 12,
      );
      expect(r.accepted, isTrue, reason: 'punto $i');
    }

    final measured = filter.totalDistanceKm * 1000;
    // El EMA deja un retraso de ~1 tramo al final; tolerancia 10 %.
    expect(measured, greaterThan(expectedMeters * 0.90));
    expect(measured, lessThanOrEqualTo(expectedMeters * 1.02));
  });

  test('un primer fix de red muy impreciso no ancla el filtro ni congela la distancia', () {
    final t0 = DateTime.now().subtract(const Duration(minutes: 10));

    // Fix de red a ~800 m del paseo real con precisión de 1 km: debe rechazarse.
    final bad = filter.processPoint(
      latitude: 4.66000,
      longitude: -74.05500,
      timestamp: t0,
      accuracyMeters: 1000,
    );
    expect(bad.accepted, isFalse);
    expect(bad.rejectReason, FilterRejectReason.accuracyTooLow);

    // Fix "aceptable" pero aún lejos (arranque en frío, 40 m): se acepta como ancla.
    final anchor = filter.processPoint(
      latitude: 4.65800,
      longitude: -74.05500,
      timestamp: t0.add(const Duration(seconds: 5)),
      accuracyMeters: 40,
    );
    expect(anchor.accepted, isTrue);

    // El GPS real está 550 m al sur: los primeros dos se rechazan por velocidad,
    // al tercero el filtro reancla sin sumar el salto y sigue midiendo.
    const realLat = 4.65300;
    const dLat = 0.0000600; // ~6.6 m
    var accepted = 0;
    for (var i = 0; i < 6; i++) {
      final r = filter.processPoint(
        latitude: realLat + dLat * i,
        longitude: -74.05500,
        timestamp: t0.add(Duration(seconds: 10 + 5 * i)),
        accuracyMeters: 8,
      );
      if (r.accepted) accepted++;
    }
    expect(accepted, greaterThanOrEqualTo(3));
    // Nunca se suman los ~550 m del salto: solo los tramos reales de ~6.6 m.
    expect(filter.totalDistanceKm * 1000, lessThan(40));
    expect(filter.totalDistanceKm * 1000, greaterThan(5));
  });

  test('ruido GPS parado no acumula distancia (deadband)', () {
    final t0 = DateTime.now().subtract(const Duration(minutes: 10));
    const lat = 4.653000, lng = -74.055000;
    // Jitter de ±1 m alrededor del mismo punto.
    const jitter = [0.0, 0.000009, -0.000009, 0.000005, -0.000005, 0.0];
    for (var i = 0; i < jitter.length; i++) {
      filter.processPoint(
        latitude: lat + jitter[i],
        longitude: lng - jitter[i],
        timestamp: t0.add(Duration(seconds: 5 * i)),
        accuracyMeters: 10,
      );
    }
    expect(filter.totalDistanceKm * 1000, lessThan(3));
  });

  test('ritmo actual se calcula sobre la ventana móvil, no exige tramos de 20 m', () {
    final t0 = DateTime.now().subtract(const Duration(minutes: 10));
    const dLat = 0.0000600; // ~6.6 m cada 5 s ≈ 4.8 km/h ≈ 12.6 min/km
    double? pace;
    for (var i = 0; i < 10; i++) {
      pace = filter
          .processPoint(
            latitude: 4.653 + dLat * i,
            longitude: -74.055,
            timestamp: t0.add(Duration(seconds: 5 * i)),
            accuracyMeters: 8,
          )
          .currentPaceMinPerKm;
    }
    expect(pace, isNotNull);
    expect(pace!, greaterThan(9));
    expect(pace, lessThan(18));
  });
}
