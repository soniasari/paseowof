import 'package:flutter_riverpod/flutter_riverpod.dart';

class WalksHistoryFormState {
  final DateTime? fechaInicio;
  final DateTime? fechaFin;

  WalksHistoryFormState({
    this.fechaInicio,
    this.fechaFin,
  });

  WalksHistoryFormState copyWith({
    DateTime? fechaInicio,
    DateTime? fechaFin,
    bool clearFechaInicio = false,
    bool clearFechaFin = false,
  }) {
    return WalksHistoryFormState(
      fechaInicio: clearFechaInicio ? null : (fechaInicio ?? this.fechaInicio),
      fechaFin: clearFechaFin ? null : (fechaFin ?? this.fechaFin),
    );
  }
}

class WalksHistoryFormController extends StateNotifier<WalksHistoryFormState> {
  WalksHistoryFormController() : super(WalksHistoryFormState());

  void setFechaInicio(DateTime? fecha) {
    state = state.copyWith(fechaInicio: fecha);
  }

  void setFechaFin(DateTime? fecha) {
    state = state.copyWith(fechaFin: fecha);
  }

  void clearFechaInicio() {
    state = state.copyWith(clearFechaInicio: true);
  }

  void clearFechaFin() {
    state = state.copyWith(clearFechaFin: true);
  }
}

final walksHistoryFormControllerProvider =
    StateNotifierProvider.autoDispose<WalksHistoryFormController, WalksHistoryFormState>((ref) {
  return WalksHistoryFormController();
});

