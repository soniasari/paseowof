import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/pressable_card_controller.dart';

// Provider para cada card (usando autoDispose para limpiar cuando no se usa)
final pressableCardControllerProvider =
    StateNotifierProvider.autoDispose.family<PressableCardController, PressableCardState, String>(
  (ref, cardId) {
    return PressableCardController();
  },
);

