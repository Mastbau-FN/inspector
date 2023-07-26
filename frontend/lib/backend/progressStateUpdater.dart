import 'package:MBG_Inspektionen/backend/failedRequestManager.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProgressStateUpdater extends ChangeNotifier {
  ProgressStateUpdater() {
    _getProgress();
  }

  double? _progress = null;
  bool? _loading = false;
  bool? _success;

  double? get progress => _progress;
  bool get loading => _loading ?? false;
  bool? get success => _success;

  //get Progress from shared Preferences frequently
  void _getProgress() async {
    _progress =
        (await SharedPreferences.getInstance()).getDouble(sync_progress_str);

    notifyListeners();

    await Future.delayed(
        Duration(milliseconds: await getLoading() == true ? 200 : 5000));

    getSuccess();
    try {
      _getProgress();
    } catch (e) {
      debugPrint('tot $e');
    }
  }

  //get Loading from shared Preferences frequently
  Future<bool?> getLoading() {
    return SharedPreferences.getInstance()
        .then((prefs) => _loading = prefs.getBool(sync_in_progress_str));
  }

  //get Success from shared Preferences frequently
  Future<bool?> getSuccess() async {
    final prefs = await SharedPreferences.getInstance();
    _success = switch (prefs.getInt(sync_success_str)) {
      0 => false,
      1 => true,
      _ => null,
    };
  }
}
