import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_colors.dart';
import '../providers/pressable_card_providers.dart';

class PressableCard extends ConsumerWidget {
  final Widget child;
  final VoidCallback? onTap;
  final String cardId;

  const PressableCard({
    super.key,
    required this.child,
    required this.cardId,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardState = ref.watch(pressableCardControllerProvider(cardId));
    final cardController = ref.read(pressableCardControllerProvider(cardId).notifier);

    return GestureDetector(
      onTapDown: (_) {
        cardController.setPressed(true);
      },
      onTapUp: (_) {
        cardController.setPressed(false);
        onTap?.call();
      },
      onTapCancel: () {
        cardController.setPressed(false);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: cardState.isPressed ? AppColors.secondary : Colors.transparent,
            width: 1,
          ),
        ),
        child: child,
      ),
    );
  }
}

