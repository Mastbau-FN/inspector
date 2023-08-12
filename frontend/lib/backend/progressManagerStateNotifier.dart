import 'package:MBG_Inspektionen/backend/failedRequestManager.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'offlineProvider.dart';
// import 'package:provider/provider.dart';

class UploadProgressWriter {
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

  UploadProgressWriter() {
    _init();
  }

  void _init() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final progress = prefs.getDouble(sync_progress_str);
    //debugPrint("Shared Prefs Double" + progress.toString());
    final loading = prefs.getBool(sync_in_progress_str);
    //debugPrint("Shared Prefs Double" + loading.toString());
    if (progress != null) setProgress(progress);
    if (loading != null) setLoading(loading);
    _initDone = true;
  }

  void setProgress(double progress) {
    _progress = progress;
    SharedPreferences.getInstance().then((value) {
      value.setDouble(sync_progress_str, progress);
    });
  }

  void setLoading(bool loading) {
    _loading = loading;
    SharedPreferences.getInstance().then((value) {
      value.setBool(sync_in_progress_str, loading);
    });
  }

  void setSuccess(bool? success) {
    _success = success;
    SharedPreferences.getInstance().then((value) {
      value.setInt(
          sync_success_str,
          switch (success) {
            true => 1,
            false => 0,
            null => -1,
          });
    });
    if (success ?? false) {
      deleteAll();
    }
  }

  void refresh() {
    _init();
  }
}
