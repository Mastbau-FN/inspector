import 'package:MBG_Inspektionen/backend/photo_batch_save_queue.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  test('auto-saves each complete batch in the background', () async {
    final savedBatches = <List<String>>[];
    final queue = PhotoBatchSaveQueue(
      batchSize: 10,
      saveBatch: (files) async {
        savedBatches.add(files.map((file) => file.name).toList());
        return 'saved';
      },
    );

    for (var i = 0; i < 25; i++) {
      queue.add(_xFile(i));
    }
    await queue.waitForBackgroundSaves();

    expect(savedBatches, [
      [for (var i = 0; i < 10; i++) 'photo_$i.jpg'],
      [for (var i = 10; i < 20; i++) 'photo_$i.jpg'],
    ]);
    expect(queue.visibleFiles.map((file) => file.name), [
      for (var i = 20; i < 25; i++) 'photo_$i.jpg',
    ]);
  });

  test('flushes the remaining photos after background batches', () async {
    final savedSizes = <int>[];
    final queue = PhotoBatchSaveQueue(
      batchSize: 10,
      saveBatch: (files) async {
        savedSizes.add(files.length);
        return 'saved';
      },
    );

    for (var i = 0; i < 23; i++) {
      queue.add(_xFile(i));
    }

    await queue.flushRemaining();

    expect(savedSizes, [10, 10, 3]);
    expect(queue.hasWork, isFalse);
  });

  test('keeps failed background batches visible for retry', () async {
    var attempts = 0;
    final queue = PhotoBatchSaveQueue(
      batchSize: 10,
      saveBatch: (files) async {
        attempts++;
        if (attempts == 1) throw Exception('temporary');
        return 'saved';
      },
    );

    for (var i = 0; i < 10; i++) {
      queue.add(_xFile(i));
    }
    await queue.waitForBackgroundSaves();

    expect(queue.visibleCount, 10);

    await queue.flushRemaining();

    expect(queue.hasWork, isFalse);
    expect(attempts, 2);
  });

  test('chunks lists by the requested size', () {
    expect(chunked([1, 2, 3, 4, 5], 2), [
      [1, 2],
      [3, 4],
      [5],
    ]);
  });
}

XFile _xFile(int index) {
  return XFile('/tmp/photo_$index.jpg', name: 'photo_$index.jpg');
}
