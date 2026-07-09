import 'package:MBG_Inspektionen/backend/failedRequestManager.dart'
    show sync_in_progress_str, sync_progress_str, sync_success_str;
import 'package:MBG_Inspektionen/backend/progressManagerStateNotifier.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('releases the backup lock before sync starts', () async {
    final backupProgress = UploadProgressWriter();
    await backupProgress.awaitInitDone();

    await backupProgress.startBackup();
    var preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool(sync_in_progress_str), isTrue);

    await backupProgress.finishBackup(success: true);
    await backupProgress.prepareForSync();

    preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool(sync_in_progress_str), isFalse);
    expect(preferences.getDouble(sync_progress_str), 0.0);
    expect(preferences.containsKey(sync_success_str), isFalse);

    final syncProgress = UploadProgressWriter();
    await syncProgress.awaitInitDone();
    expect(syncProgress.loading, isFalse);
  });
}
