import 'package:flutter_riverpod/flutter_riverpod.dart';

class RescheduleWalkFormState {
  final DateTime selectedDate;
  final String? horaInicio;
  final String? horaFin;
  final String? selectedCaninoId;

  RescheduleWalkFormState({
    required this.selectedDate,
    this.horaInicio,
    this.horaFin,
    this.selectedCaninoId,
  });

  RescheduleWalkFormState copyWith({
    DateTime? selectedDate,
    String? horaInicio,
    String? horaFin,
    String? selectedCaninoId,
    bool clearHoraFin = false,
    bool clearCaninoId = false,
  }) {
    return RescheduleWalkFormState(
      selectedDate: selectedDate ?? this.selectedDate,
      horaInicio: horaInicio ?? this.horaInicio,
      horaFin: clearHoraFin ? null : (horaFin ?? this.horaFin),
      selectedCaninoId: clearCaninoId ? null : (selectedCaninoId ?? this.selectedCaninoId),
    );
  }
}

class RescheduleWalkFormController extends StateNotifier<RescheduleWalkFormState> {
  RescheduleWalkFormController(DateTime initialDate)
      : super(RescheduleWalkFormState(selectedDate: initialDate));

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
}

final rescheduleWalkFormControllerProvider =
    StateNotifierProvider.autoDispose.family<RescheduleWalkFormController, RescheduleWalkFormState, DateTime>((ref, initialDate) {
  return RescheduleWalkFormController(initialDate);
});

