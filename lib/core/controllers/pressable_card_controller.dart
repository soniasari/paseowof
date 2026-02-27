import 'package:flutter_riverpod/flutter_riverpod.dart';

class PressableCardState {
  final bool isPressed;

  const PressableCardState({
    this.isPressed = false,
  });

  PressableCardState copyWith({
    bool? isPressed,
  }) {
    return PressableCardState(
      isPressed: isPressed ?? this.isPressed,
    );
  }
}

class PressableCardController extends StateNotifier<PressableCardState> {
  PressableCardController() : super(const PressableCardState());

  void setPressed(bool pressed) {
    state = state.copyWith(isPressed: pressed);
  }
}

