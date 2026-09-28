import 'package:flutter_test/flutter_test.dart';
import 'package:paseowof/features/walks/data/datasources/walk_progress_local_data_source.dart';
import 'package:paseowof/features/walks/data/repositories/walk_progress_repository_impl.dart';
import 'package:paseowof/features/walks/domain/entities/gps_point.dart';
import 'package:paseowof/features/walks/domain/entities/walk_progress.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late WalkProgressRepositoryImpl repository;

  WalkProgress progress({String walkId = 'w1', DateTime? savedAt}) {
    final t0 = DateTime(2026, 9, 27, 18, 0);
    return WalkProgress(
      walkId: walkId,
      paseadorId: 'p1',
      startTime: t0,
      totalPausedSeconds: 30,
      pausedAt: null,
      distanceKm: 0.312,
      points: [
        GpsPoint(latitude: -16.4999, longitude: -68.1201, timestamp: t0, accuracy: 5),
        GpsPoint(
          latitude: -16.4980,
          longitude: -68.1212,
          timestamp: t0.add(const Duration(minutes: 4)),
        ),
      ],
      savedAt: savedAt ?? DateTime.now(),
    );
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repository = WalkProgressRepositoryImpl(WalkProgressLocalDataSourceImpl());
  });

  test('guarda y recupera el progreso del mismo paseo', () async {
    await repository.save(progress());
    final loaded = await repository.getFor(walkId: 'w1', paseadorId: 'p1');

    expect(loaded, isNotNull);
    expect(loaded!.distanceKm, 0.312);
    expect(loaded.totalPausedSeconds, 30);
    expect(loaded.points.length, 2);
    expect(loaded.points.first.accuracy, 5);
    expect(loaded.points.last.accuracy, isNull);
    expect(loaded.points.last.timestamp, DateTime(2026, 9, 27, 18, 4));
  });

  test('no retoma el progreso de otro paseo', () async {
    await repository.save(progress(walkId: 'otro'));
    expect(await repository.getFor(walkId: 'w1', paseadorId: 'p1'), isNull);
  });

  test('descarta un progreso guardado hace más de 12 h', () async {
    await repository.save(progress(savedAt: DateTime.now().subtract(const Duration(hours: 13))));
    expect(await repository.getFor(walkId: 'w1', paseadorId: 'p1'), isNull);
  });

  test('clear borra el progreso', () async {
    await repository.save(progress());
    await repository.clear();
    expect(await repository.getFor(walkId: 'w1', paseadorId: 'p1'), isNull);
  });
}
