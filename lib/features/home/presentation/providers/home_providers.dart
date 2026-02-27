import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/home_navigation_controller.dart';

// Provider del HomeNavigationController
final homeNavigationControllerProvider =
    StateNotifierProvider<HomeNavigationController, int>((ref) {
  return HomeNavigationController();
});

