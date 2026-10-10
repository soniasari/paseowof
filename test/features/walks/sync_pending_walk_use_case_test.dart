import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:paseowof/features/walks/data/datasources/walk_progress_local_data_source.dart';
import 'package:paseowof/features/walks/data/repositories/walk_progress_repository_impl.dart';
import 'package:paseowof/features/walks/domain/entities/walk_progress.dart';
import 'package:paseowof/features/walks/domain/repositories/walks_repository.dart';
import 'package:paseowof/features/walks/domain/use_cases/sync_pending_walk_use_case.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _QueueWalksRepository implements WalksRepository {
  final Completer<void> serverAck = Completer<void>();
  int waits = 0;

  @override
  Future<void> waitForPendingWrites() {
    waits++;
    return serverAck.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  late WalkProgressRepositoryImpl progress;
  late _QueueWalksRepository walks;
  late SyncPendingWalkUseCase useCase;

  WalkProgress pendingWalk(String walkId) => WalkProgress(
        walkId: walkId,
        paseadorId: 'p1',
        startTime: DateTime(2026, 9, 27, 18),
        totalPausedSeconds: 0,
        pausedAt: null,
        distanceKm: 0.4,
        points: const [],
        savedAt: DateTime.now(),
      );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    progress = WalkProgressRepositoryImpl(WalkProgressLocalDataSourceImpl());
    walks = _QueueWalksRepository();
    useCase = SyncPendingWalkUseCase(walks, progress);
  });

  test('sin pendientes no espera al servidor', () async {
    expect(await useCase.execute(), 0);
    expect(walks.waits, 0);
  });

  test('borra los pendientes solo cuando el servidor confirma', () async {
    await progress.addPendingSync(pendingWalk('w1'));
    await progress.addPendingSync(pendingWalk('w2'));

    final run = useCase.execute();
    await Future<void>.delayed(Duration.zero);
    expect(await progress.getPendingSync(), hasLength(2), reason: 'aún sin internet');

    walks.serverAck.complete();
    expect(await run, 2);
    expect(await progress.getPendingSync(), isEmpty);
  });
}
