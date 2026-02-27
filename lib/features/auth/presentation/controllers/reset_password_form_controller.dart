import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ResetPasswordFormState {
  final String message;
  final Color messageColor;
  final bool isLoading;
  final bool emailSent;

  ResetPasswordFormState({
    this.message = '',
    this.messageColor = Colors.blue,
    this.isLoading = false,
    this.emailSent = false,
  });

  ResetPasswordFormState copyWith({
    String? message,
    Color? messageColor,
    bool? isLoading,
    bool? emailSent,
  }) {
    return ResetPasswordFormState(
      message: message ?? this.message,
      messageColor: messageColor ?? this.messageColor,
      isLoading: isLoading ?? this.isLoading,
      emailSent: emailSent ?? this.emailSent,
    );
  }
}

class ResetPasswordFormController extends StateNotifier<ResetPasswordFormState> {
  ResetPasswordFormController() : super(ResetPasswordFormState());

  void setMessage(String message, Color color) {
    state = state.copyWith(message: message, messageColor: color);
  }

  void setLoading(bool loading) {
    state = state.copyWith(isLoading: loading);
  }

  void clearMessage() {
    state = state.copyWith(message: '');
  }

  void setEmailSent(bool sent) {
    state = state.copyWith(emailSent: sent);
  }
}

final resetPasswordFormControllerProvider =
    StateNotifierProvider.autoDispose<ResetPasswordFormController, ResetPasswordFormState>((ref) {
  return ResetPasswordFormController();
});

