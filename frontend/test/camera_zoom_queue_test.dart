import 'dart:async';

import 'package:MBG_Inspektionen/fragments/camera/cameraModel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Zoom queue applies the active and latest requested value only',
      () async {
    final firstApplyStarted = Completer<void>();
    final allowFirstApplyToFinish = Completer<void>();
    final applied = <double>[];

    final queue = LatestAsyncValueQueue<double>((value) async {
      applied.add(value);
      if (applied.length == 1) {
        firstApplyStarted.complete();
        await allowFirstApplyToFinish.future;
      }
    });

    final first = queue.add(1.2);
    await firstApplyStarted.future;
    queue.add(1.4);
    queue.add(1.8);
    queue.add(2.3);
    allowFirstApplyToFinish.complete();

    await first;
    await queue.waitForIdle();

    expect(applied, <double>[1.2, 2.3]);
  });

  test('closed zoom queue ignores further values', () async {
    final applied = <double>[];
    final queue = LatestAsyncValueQueue<double>((value) async {
      applied.add(value);
    });

    queue.close();
    await queue.add(3.0);

    expect(applied, isEmpty);
  });
}
