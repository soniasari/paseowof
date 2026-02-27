import 'package:flutter_riverpod/flutter_riverpod.dart';

class WalksByClientFormState {
  final DateTime? fechaInicio;
  final DateTime? fechaFin;
  final String? selectedOwnerId;

  WalksByClientFormState({
    this.fechaInicio,
    this.fechaFin,
    this.selectedOwnerId,
  });

  WalksByClientFormState copyWith({
    DateTime? fechaInicio,
    DateTime? fechaFin,
    String? selectedOwnerId,
    bool clearFechaInicio = false,
    bool clearFechaFin = false,
    bool clearSelectedOwnerId = false,
  }) {
    return WalksByClientFormState(
      fechaInicio: clearFechaInicio ? null : (fechaInicio ?? this.fechaInicio),
      fechaFin: clearFechaFin ? null : (fechaFin ?? this.fechaFin),
      selectedOwnerId: clearSelectedOwnerId ? null : (selectedOwnerId ?? this.selectedOwnerId),
    );
  }
}

class WalksByClientFormController extends StateNotifier<WalksByClientFormState> {
  WalksByClientFormController() : super(WalksByClientFormState());

  void setFechaInicio(DateTime? fecha) {
    state = state.copyWith(fechaInicio: fecha);
  }

  void setFechaFin(DateTime? fecha) {
    state = state.copyWith(fechaFin: fecha);
  }

  void setSelectedOwnerId(String? ownerId) {
    state = state.copyWith(selectedOwnerId: ownerId);
  }

  void clearFechaInicio() {
    state = state.copyWith(clearFechaInicio: true);
  }

  void clearFechaFin() {
    state = state.copyWith(clearFechaFin: true);
  }

  void clearSelectedOwnerId() {
    state = state.copyWith(clearSelectedOwnerId: true);
  }
}

final walksByClientFormControllerProvider =
    StateNotifierProvider.autoDispose<WalksByClientFormController, WalksByClientFormState>((ref) {
  return WalksByClientFormController();
});

