import '../../domain/entities/location_fix.dart';
import '../../domain/repositories/walk_location_repository.dart';
import '../datasources/walk_location_data_source.dart';
import '../mappers/location_fix_mapper.dart';

class WalkLocationRepositoryImpl implements WalkLocationRepository {
  final WalkLocationDataSource _dataSource;

  WalkLocationRepositoryImpl(this._dataSource);

  @override
  Future<void> startUpdates({
    required void Function(LocationFix fix) onFix,
    void Function(Object error)? onError,
  }) {
    return _dataSource.listen(
      (position) => onFix(LocationFixMapper.fromPosition(position)),
      onError: onError,
    );
  }

  @override
  Future<void> restartUpdates({
    required void Function(LocationFix fix) onFix,
    void Function(Object error)? onError,
  }) {
    return _dataSource.restart(
      (position) => onFix(LocationFixMapper.fromPosition(position)),
      onError: onError,
    );
  }

  @override
  Future<void> stopUpdates() => _dataSource.cancel();

  @override
  Future<LocationFix?> getCurrentFix() async {
    final position = await _dataSource.getCurrentPosition();
    return position == null ? null : LocationFixMapper.fromPosition(position);
  }

  @override
  Future<LocationFix?> getLastKnownFix() async {
    final position = await _dataSource.getLastKnownPosition();
    return position == null ? null : LocationFixMapper.fromPosition(position);
  }

  @override
  String get providerLabel => _dataSource.usingLocationManager ? 'LM' : 'fused';
}
