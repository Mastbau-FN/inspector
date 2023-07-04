import 'package:MBG_Inspektionen/backend/failedRequestManager.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
// import 'package:provider/provider.dart';

class UploadProgressStateNotifier extends ChangeNotifier {
  double? _progress = null;
  bool _loading = false;
  bool? _success;
  bool _initDone = false;

  Future awaitInitDone() async {
    while (!_initDone) {
      await Future.delayed(Duration(milliseconds: 100));
    }
  }

  double? get progress => _progress;
  bool get loading => _loading;
  bool? get success => _success;

  UploadProgressStateNotifier() {
    _init();
  }

  void _init() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final progress = prefs.getDouble(sync_progress_str);
    final loading = prefs.getBool(sync_in_progress_str);
    if (progress != null) setProgress(progress);
    if (loading != null) setLoading(loading);
    _initDone = true;
  }

  void setProgress(double progress) {
    _progress = progress;
    notifyListeners();
    SharedPreferences.getInstance().then((value) {
      value.setDouble(sync_progress_str, progress);
    });
  }

  void setLoading(bool loading) {
    _loading = loading;
    notifyListeners();
    SharedPreferences.getInstance().then((value) {
      value.setBool(sync_in_progress_str, loading);
    });
  }

  void setSuccess(bool? success) {
    _success = success;
    notifyListeners();
  }

  void refresh() {
    _init();
  }
}
