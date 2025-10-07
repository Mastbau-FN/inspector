import 'dart:io';

import 'package:MBG_Inspektionen/backend/failedRequestManager.dart';
import 'package:MBG_Inspektionen/pages/settings/settingsView.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'offlineProvider.dart';
// import 'package:provider/provider.dart';

// UploadProgressWriter class for managing backup progress
class UploadProgressWriter {
  double? _progress;
  bool _loading = false;
  bool? _success;
  bool _initDone = false;

  UploadProgressWriter() {
    init();
  }

  Future<void> init() async {
    await _init();
  }

  Future<void> awaitInitDone() async {
    while (!_initDone) {
      await Future.delayed(Duration(milliseconds: 100));
    }
  }

  double? get progress => _progress;
  bool get loading => _loading;
  bool? get success => _success;

  Future<void> _init() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final progress = prefs.getDouble('sync_progress_str');
      final loading = prefs.getBool('sync_in_progress_str');

      if (progress != null) setProgress(progress);
      if (loading != null) setLoading(loading);

      _initDone = true;
    } catch (e) {
      debugPrint('Error initializing UploadProgressWriter: $e');
    }
  }

  Future<void> setProgress(double progress) async {
    _progress = progress;
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('sync_progress_str', progress);
    } catch (e) {
      debugPrint('Error setting progress: $e');
    }
  }

  Future<void> setLoading(bool loading) async {
    _loading = loading;
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool('sync_in_progress_str', loading);
    } catch (e) {
      debugPrint('Error setting loading state: $e');
    }
  }

  Future<void> setSuccess(bool? success) async {
    _success = success;
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
          'sync_success_str',
          success == true
              ? 1
              : success == false
                  ? 0
                  : -1);

      if (success == true) {
        await _performBackupAndCleanup();
      }
    } catch (e) {
      debugPrint('Error setting success: $e');
    }
  }

  Future<void> _performBackupAndCleanup() async {
    try {
      // Get the user's external storage directory
      Directory? externalDir = await getExternalStorageDirectory();
      if (externalDir != null) {
        // Create MBGBackups folder in external storage
        final backupDir = Directory('${externalDir.parent.path}/MBGBackups');
        if (!await backupDir.exists()) {
          await backupDir.create();
        }

        // Define the backup file path within MBGBackups
        final backupPath =
            '${backupDir.path}/inspector-automatic-backup-${DateTime.now().millisecondsSinceEpoch}.zip';

        // Listen to backup progress and update state
        await for (double progressValue in backup(backupPath)) {
          setProgress(progressValue);
          debugPrint(
              'Backup Progress: ${(progressValue * 100).toStringAsFixed(2)}%');
        }

        debugPrint('Automatic backup saved to $backupPath');
        // Implement deleteAll as needed
      }
    } catch (e) {
      debugPrint('Error performing backup and cleanup: $e');
    }
  }

  void refresh() {
    _init();
  }
}
