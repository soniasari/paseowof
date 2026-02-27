import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class OwnerFormState {
  final String message;
  final Color messageColor;
  final bool isLoading;

  const OwnerFormState({
    this.message = '',
    this.messageColor = Colors.transparent,
    this.isLoading = false,
  });

  OwnerFormState copyWith({
    String? message,
    Color? messageColor,
    bool? isLoading,
  }) {
    return OwnerFormState(
      message: message ?? this.message,
      messageColor: messageColor ?? this.messageColor,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class OwnerFormController extends StateNotifier<OwnerFormState> {
  OwnerFormController() : super(const OwnerFormState());

  void setLoading(bool isLoading) {
    state = state.copyWith(isLoading: isLoading);
  }

  void setMessage(String message, Color color) {
    state = state.copyWith(message: message, messageColor: color);
  }

  void clearMessage() {
    state = const OwnerFormState();
  }
}

final ownerFormControllerProvider = StateNotifierProvider.autoDispose<OwnerFormController, OwnerFormState>(
  (ref) => OwnerFormController(),
);

