import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LoginFormState {
  final String message;
  final Color messageColor;
  final bool isLoading;

  const LoginFormState({
    this.message = '',
    this.messageColor = Colors.transparent,
    this.isLoading = false,
  });

  LoginFormState copyWith({
    String? message,
    Color? messageColor,
    bool? isLoading,
  }) {
    return LoginFormState(
      message: message ?? this.message,
      messageColor: messageColor ?? this.messageColor,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class LoginFormController extends StateNotifier<LoginFormState> {
  LoginFormController() : super(const LoginFormState());

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

