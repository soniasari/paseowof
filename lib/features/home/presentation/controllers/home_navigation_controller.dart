import 'package:flutter_riverpod/flutter_riverpod.dart';

class HomeNavigationController extends StateNotifier<int> {
  HomeNavigationController() : super(0);

  void setIndex(int index) {
    state = index;
  }
}

