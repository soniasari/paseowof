import 'package:flutter_riverpod/flutter_riverpod.dart';

class ScheduleWalkFormState {
  final DateTime selectedDate;
  final String? horaInicio;
  final String? horaFin;
  final String? selectedCaninoId;
  final String? lastLoadedDireccion;

  ScheduleWalkFormState({
    required this.selectedDate,
    this.horaInicio,
    this.horaFin,
    this.selectedCaninoId,
    this.lastLoadedDireccion,
  });

  ScheduleWalkFormState copyWith({
    DateTime? selectedDate,
    String? horaInicio,
    String? horaFin,
    String? selectedCaninoId,
    String? lastLoadedDireccion,
    bool clearHoraFin = false,
    bool clearCaninoId = false,
    bool clearLastLoadedDireccion = false,
  }) {
    return ScheduleWalkFormState(
      selectedDate: selectedDate ?? this.selectedDate,
      horaInicio: horaInicio ?? this.horaInicio,
      horaFin: clearHoraFin ? null : (horaFin ?? this.horaFin),
      selectedCaninoId: clearCaninoId ? null : (selectedCaninoId ?? this.selectedCaninoId),
      lastLoadedDireccion: clearLastLoadedDireccion ? null : (lastLoadedDireccion ?? this.lastLoadedDireccion),
    );
  }
}

class ScheduleWalkFormController extends StateNotifier<ScheduleWalkFormState> {
  ScheduleWalkFormController()
      : super(ScheduleWalkFormState(selectedDate: DateTime.now()));

  void setSelectedDate(DateTime date) {
    state = state.copyWith(
      selectedDate: date,
      horaInicio: null,
      horaFin: null,
      clearHoraFin: true,
    );
  }

  void setHoraInicio(String? horaInicio) {
    state = state.copyWith(
      horaInicio: horaInicio,
      clearHoraFin: true,
    );
  }

  void setHoraFin(String? horaFin) {
    state = state.copyWith(horaFin: horaFin);
  }

  void setSelectedCaninoId(String? caninoId) {
    state = state.copyWith(selectedCaninoId: caninoId);
  }

  void setLastLoadedDireccion(String? direccion) {
    state = state.copyWith(lastLoadedDireccion: direccion);
  }

  void clearLastLoadedDireccion() {
    state = state.copyWith(clearLastLoadedDireccion: true);
  }

  void reset() {
    state = ScheduleWalkFormState(selectedDate: DateTime.now());
  }
}

final scheduleWalkFormControllerProvider =
    StateNotifierProvider.autoDispose<ScheduleWalkFormController, ScheduleWalkFormState>((ref) {
  return ScheduleWalkFormController();
});

