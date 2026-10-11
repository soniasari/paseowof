import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:paseowof/features/walks/domain/entities/complete_walk_result.dart';
import 'package:paseowof/features/walks/domain/entities/gps_point.dart';
import 'package:paseowof/features/walks/domain/entities/location_fix.dart';
import 'package:paseowof/features/walks/domain/entities/walk.dart';
import 'package:paseowof/features/walks/domain/entities/walk_pet.dart';
import 'package:paseowof/features/walks/domain/entities/walk_progress.dart';
import 'package:paseowof/features/walks/domain/repositories/walk_location_repository.dart';
import 'package:paseowof/features/walks/domain/repositories/walk_progress_repository.dart';
import 'package:paseowof/features/walks/domain/repositories/walks_repository.dart';
import 'package:paseowof/features/walks/domain/use_cases/complete_walk_with_track_use_case.dart';
import 'package:paseowof/features/walks/presentation/walk_in_progress/walk_in_progress_notifier.dart';

class _FakeLocationRepository implements WalkLocationRepository {
  void Function(LocationFix fix)? _onFix;
  int startCalls = 0;
  int restartCalls = 0;
  int stopCalls = 0;

  void emit(LocationFix fix) => _onFix?.call(fix);

  @override
  Future<void> startUpdates({
    required void Function(LocationFix fix) onFix,
    void Function(Object error)? onError,
  }) async {
    startCalls++;
    _onFix = onFix;
  }

  @override
  Future<void> restartUpdates({
    required void Function(LocationFix fix) onFix,
    void Function(Object error)? onError,
  }) async {
    restartCalls++;
    _onFix = onFix;
  }

  @override
  Future<void> stopUpdates() async {
    stopCalls++;
    _onFix = null;
  }

  @override
  Future<LocationFix?> getCurrentFix() async => null;

  @override
  Future<LocationFix?> getLastKnownFix() async => null;

  @override
  String get providerLabel => 'fake';
}

class _FakeProgressRepository implements WalkProgressRepository {
  WalkProgress? stored;
  int saves = 0;

  @override
  Future<void> save(WalkProgress progress) async {
    saves++;
    stored = progress;
  }

  @override
  Future<WalkProgress?> getFor({required String walkId, required String paseadorId}) async {
    final p = stored;
    if (p == null || p.walkId != walkId || p.paseadorId != paseadorId) return null;
    return p;
  }

  @override
  Future<void> clear() async => stored = null;

  final Map<String, WalkProgress> pending = {};

  @override
  Future<void> addPendingSync(WalkProgress progress) async => pending[progress.walkId] = progress;

  @override
  Future<List<WalkProgress>> getPendingSync() async => pending.values.toList();

  @override
  Future<void> removePendingSync(String walkId) async => pending.remove(walkId);
}

/// Simula el servidor: con [online] confirma al instante; sin él la escritura
/// queda en cola hasta llamar a [reconnect].
class _FakeWalksRepository implements WalksRepository {
  _FakeWalksRepository(this.walk);

  final Walk walk;
  bool online = true;
  Walk? savedWalk;
  List<GpsPoint>? savedPoints;
  final Completer<void> _serverAck = Completer<void>();

  void reconnect() {
    if (!_serverAck.isCompleted) _serverAck.complete();
  }

  @override
  Future<Walk?> getWalkById(String paseadorId, String walkId) async => walk;

  @override
  Future<List<WalkPet>> getWalkPetsByPaseoId(String paseadorId, String paseoId) async => [
        WalkPet(id: 'wp1', paseoId: paseoId, caninoId: 'c1', nombreCanino: 'Firulais'),
      ];

  @override
  Future<CompleteWalkResult> completeWalkWithTrack(
    Walk completedWalk,
    List<GpsPoint> points, {
    required List<String> idsMascotas,
    required String nombreMascota,
    required double distanciaKm,
    required int duracionRealMinutos,
  }) async {
    savedWalk = completedWalk;
    savedPoints = points;
    if (online) return CompleteWalkResult(synced: true, whenSynced: Future<void>.value());
    return CompleteWalkResult(synced: false, whenSynced: _serverAck.future);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

Future<void> _flush() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late _FakeLocationRepository location;
  late _FakeProgressRepository progress;
  late _FakeWalksRepository walks;
  late WalkInProgressNotifier notifier;

  final now = DateTime.now();
  final walk = Walk(
    id: 'w1',
    paseadorId: 'p1',
    propietarioId: 'o1',
    fechaPaseo: now,
    horaInicio: '18:00',
    fechaCreacion: now,
    fechaModificacion: now,
  );

  setUp(() {
    location = _FakeLocationRepository();
    progress = _FakeProgressRepository();
    walks = _FakeWalksRepository(walk);
    notifier = WalkInProgressNotifier(
      completeWalkWithTrackUseCase: CompleteWalkWithTrackUseCase(walks),
      locationRepository: location,
      progressRepository: progress,
    );
  });

  tearDown(() => notifier.dispose());

  test('acumula distancia con lecturas del GPS y guarda el progreso local', () async {
    await notifier.startTracking(walk, 'p1');
    expect(location.startCalls, 1);

    // ~6.6 m cada 5 s hacia el norte (~4.8 km/h), fixes de los últimos 60 s.
    final t0 = DateTime.now().subtract(const Duration(seconds: 60));
    for (var i = 0; i < 12; i++) {
      location.emit(LocationFix(
        latitude: -16.4999 + 0.00006 * i,
        longitude: -68.1201,
        timestamp: t0.add(Duration(seconds: 5 * i)),
        accuracy: 5,
      ));
    }
    await _flush();

    expect(notifier.state.gpsPointsCount, 12);
    expect(notifier.state.distanceKm, greaterThan(0.05));
    expect(notifier.state.distanceKm, lessThan(0.08));
    expect(progress.stored, isNotNull);

    notifier.onAppLifecycleChanged(inForeground: false);
    await _flush();
    expect(progress.stored!.points.length, 12, reason: 'al ir a segundo plano se guarda todo');
  });

  test('retoma un paseo guardado en el teléfono', () async {
    final t0 = DateTime.now().subtract(const Duration(minutes: 5));
    progress.stored = WalkProgress(
      walkId: 'w1',
      paseadorId: 'p1',
      startTime: t0,
      totalPausedSeconds: 0,
      pausedAt: null,
      distanceKm: 0.2,
      points: [
        GpsPoint(latitude: -16.4999, longitude: -68.1201, timestamp: t0),
        GpsPoint(latitude: -16.4990, longitude: -68.1201, timestamp: t0.add(const Duration(minutes: 3))),
      ],
      savedAt: DateTime.now(),
    );

    await notifier.startTracking(walk, 'p1');

    expect(notifier.state.distanceKm, 0.2);
    expect(notifier.state.gpsPointsCount, 2);
    expect(notifier.state.elapsedSeconds, greaterThanOrEqualTo(299));
    expect(notifier.state.infoMessage, contains('200 m'));
  });

  test('salir confirmado detiene el GPS y borra el progreso', () async {
    await notifier.startTracking(walk, 'p1');
    await _flush();
    expect(progress.stored, isNotNull);

    await notifier.cancel();
    await _flush();

    expect(location.stopCalls, greaterThanOrEqualTo(1));
    expect(progress.stored, isNull);
    expect(notifier.state.hasWalk, isFalse);
  });

  /// Camina hacia el norte hasta tener [count] puntos aceptados.
  Future<void> walkPoints(int count) async {
    final t0 = DateTime.now().subtract(Duration(seconds: 5 * count));
    for (var i = 0; i < count; i++) {
      location.emit(LocationFix(
        latitude: -16.4999 + 0.00006 * i,
        longitude: -68.1201,
        timestamp: t0.add(Duration(seconds: 5 * i)),
        accuracy: 5,
      ));
    }
    await _flush();
  }

  test('con internet: finaliza, guarda la ruta y borra el respaldo', () async {
    await notifier.startTracking(walk, 'p1');
    await walkPoints(20);

    final synced = await notifier.finishWalk();
    await _flush();

    expect(synced, isTrue);
    expect(walks.savedPoints, hasLength(15));
    expect(walks.savedWalk!.estado, 'completado');
    expect(progress.stored, isNull);
    expect(progress.pending, isEmpty);
    expect(notifier.state.hasWalk, isFalse);
  });

  test('sin internet: finaliza sin colgarse y conserva la ruta hasta que se sube', () async {
    walks.online = false;
    await notifier.startTracking(walk, 'p1');
    await walkPoints(20);

    final synced = await notifier.finishWalk();
    await _flush();

    expect(synced, isFalse);
    expect(notifier.state.hasWalk, isFalse);
    expect(progress.stored, isNull, reason: 'no debe ofrecer retomar un paseo ya finalizado');
    expect(progress.pending.keys, ['w1']);
    expect(progress.pending['w1']!.points, hasLength(20));

    walks.reconnect();
    await _flush();
    expect(progress.pending, isEmpty, reason: 'el servidor confirmó: ya no hace falta el respaldo');
  });

  test('un paseo nuevo no borra la ruta pendiente de otro', () async {
    walks.online = false;
    await notifier.startTracking(walk, 'p1');
    await walkPoints(20);
    await notifier.finishWalk();
    await _flush();

    final otherWalk = Walk(
      id: 'w2',
      paseadorId: 'p1',
      propietarioId: 'o1',
      fechaPaseo: now,
      horaInicio: '19:00',
      fechaCreacion: now,
      fechaModificacion: now,
    );
    await notifier.startTracking(otherWalk, 'p1');
    await _flush();

    expect(progress.stored!.walkId, 'w2');
    expect(progress.pending.keys, ['w1']);
  });
}
