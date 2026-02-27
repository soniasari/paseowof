import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PetFormState {
  final String message;
  final Color messageColor;
  final bool isLoading;

  const PetFormState({
    this.message = '',
    this.messageColor = Colors.transparent,
    this.isLoading = false,
  });

  PetFormState copyWith({
    String? message,
    Color? messageColor,
    bool? isLoading,
  }) {
    return PetFormState(
      message: message ?? this.message,
      messageColor: messageColor ?? this.messageColor,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class PetFormController extends StateNotifier<PetFormState> {
  PetFormController() : super(const PetFormState());

  void setLoading(bool isLoading) {
    state = state.copyWith(isLoading: isLoading);
  }

  void setMessage(String message, Color color) {
    state = state.copyWith(message: message, messageColor: color);
  }

  void clearMessage() {
    state = const PetFormState();
  }
}

final petFormControllerProvider = StateNotifierProvider.autoDispose<PetFormController, PetFormState>(
  (ref) => PetFormController(),
);

