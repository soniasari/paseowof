import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class WalkFormState {
  final String message;
  final Color messageColor;
  final bool isLoading;

  const WalkFormState({
    this.message = '',
    this.messageColor = Colors.transparent,
    this.isLoading = false,
  });

  WalkFormState copyWith({
    String? message,
    Color? messageColor,
    bool? isLoading,
  }) {
    return WalkFormState(
      message: message ?? this.message,
      messageColor: messageColor ?? this.messageColor,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class WalkFormController extends StateNotifier<WalkFormState> {
  WalkFormController() : super(const WalkFormState());

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

