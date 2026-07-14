import 'package:flutter/foundation.dart';

import 'package:MBG_Inspektionen/backend/categoryProgressState.dart';

class SyncEvents {
  static final SyncEvents instance = SyncEvents._internal();
  SyncEvents._internal();

  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  void notifyLocalDataChanged() {
    revision.value = revision.value + 1;
  }

  void notifySyncCompleted() {
    CategoryProgressState.instance.resetAllInspectionProgress();
    notifyLocalDataChanged();
  }
}
