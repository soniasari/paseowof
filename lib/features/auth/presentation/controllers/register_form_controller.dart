import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RegisterFormState {
  final String message;
  final Color messageColor;
  final bool isLoading;

  const RegisterFormState({
    this.message = '',
    this.messageColor = Colors.transparent,
    this.isLoading = false,
  });

  RegisterFormState copyWith({
    String? message,
    Color? messageColor,
    bool? isLoading,
  }) {
    return RegisterFormState(
      message: message ?? this.message,
      messageColor: messageColor ?? this.messageColor,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class RegisterFormController extends StateNotifier<RegisterFormState> {
  RegisterFormController() : super(const RegisterFormState());

  void setLoading(bool isLoading) {
    state = state.copyWith(isLoading: isLoading);
  }

  void setMessage(String message, Color color) {
    state = state.copyWith(message: message, messageColor: color);
  }

  void clearMessage() {
    state = state.copyWith(message: '', messageColor: Colors.transparent);
  }
}

