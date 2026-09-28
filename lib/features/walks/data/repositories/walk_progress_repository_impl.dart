import '../../domain/entities/walk_progress.dart';
import '../../domain/repositories/walk_progress_repository.dart';
import '../datasources/walk_progress_local_data_source.dart';
import '../mappers/walk_progress_mapper.dart';

class WalkProgressRepositoryImpl implements WalkProgressRepository {
  final WalkProgressLocalDataSource _localDataSource;

  WalkProgressRepositoryImpl(this._localDataSource);

  /// Un paseo guardado hace más de esto ya no se retoma.
  static const Duration maxAge = Duration(hours: 12);

  @override
  Future<void> save(WalkProgress progress) {
    return _localDataSource.write(WalkProgressMapper.toJson(progress));
  }

  @override
  Future<WalkProgress?> getFor({required String walkId, required String paseadorId}) async {
    final json = await _localDataSource.read();
    if (json == null) return null;
    final WalkProgress progress;
    try {
      progress = WalkProgressMapper.fromJson(json);
    } catch (_) {
      await _localDataSource.delete();
      return null;
    }
    if (progress.walkId != walkId || progress.paseadorId != paseadorId) return null;
    if (DateTime.now().difference(progress.savedAt) > maxAge) {
      await _localDataSource.delete();
      return null;
    }
    return progress;
  }

  @override
  Future<void> clear() => _localDataSource.delete();
}
