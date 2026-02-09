import 'package:flutter/foundation.dart';

class SyncEvents {
  static final SyncEvents instance = SyncEvents._internal();
  SyncEvents._internal();

  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  void notifyLocalDataChanged() {
    revision.value = revision.value + 1;
  }
}

