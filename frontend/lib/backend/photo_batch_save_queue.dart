import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

const int defaultPhotoBatchSize = 10;

typedef PhotoBatchSaver = Future<String?> Function(List<XFile> files);
typedef PhotoBatchErrorHandler = void Function(
  Object error,
  StackTrace stackTrace,
);

class PhotoBatchSaveQueue {
  PhotoBatchSaveQueue({
    required this.saveBatch,
    this.batchSize = defaultPhotoBatchSize,
    this.onChanged,
    this.onBackgroundError,
  }) : assert(batchSize > 0);

  final PhotoBatchSaver saveBatch;
  final int batchSize;
  final VoidCallback? onChanged;
  final PhotoBatchErrorHandler? onBackgroundError;

  final List<XFile> _visibleFiles = [];
  final List<List<XFile>> _backgroundBatches = [];
  Future<void>? _backgroundDrain;
  bool _disposed = false;

  List<XFile> get visibleFiles => List.unmodifiable(_visibleFiles);
  int get visibleCount => _visibleFiles.length;
  bool get hasVisibleFiles => _visibleFiles.isNotEmpty;
  bool get hasBackgroundWork =>
      _backgroundBatches.isNotEmpty || _backgroundDrain != null;
  bool get hasWork => hasVisibleFiles || hasBackgroundWork;

  void add(XFile file) {
    _visibleFiles.add(file);
    _scheduleCompleteBatches();
    _notifyChanged();
  }

  XFile? removeLastVisible() {
    if (_visibleFiles.isEmpty) return null;
    final file = _visibleFiles.removeLast();
    _notifyChanged();
    return file;
  }

  Future<String?> flushRemaining() async {
    await waitForBackgroundSaves();
    if (_visibleFiles.isEmpty) return null;

    final batch = List<XFile>.from(_visibleFiles);
    _visibleFiles.clear();
    _notifyChanged();
    return saveBatch(batch);
  }

  Future<void> waitForBackgroundSaves() async {
    while (true) {
      final drain = _backgroundDrain;
      if (drain == null) return;
      await drain;
    }
  }

  void dispose() {
    _disposed = true;
  }

  void _scheduleCompleteBatches() {
    while (_visibleFiles.length >= batchSize) {
      final batch = _visibleFiles.take(batchSize).toList();
      _visibleFiles.removeRange(0, batchSize);
      _backgroundBatches.add(batch);
    }
    if (_backgroundBatches.isNotEmpty) {
      _ensureBackgroundDrain();
    }
  }

  void _ensureBackgroundDrain() {
    if (_backgroundDrain != null) return;
    final drain = _drainBackgroundBatches();
    _backgroundDrain = drain;
    unawaited(drain);
  }

  Future<void> _drainBackgroundBatches() async {
    try {
      // Already accepted batches must finish even if their gallery page is
      // disposed while the user moves to the next checkpoint.
      while (_backgroundBatches.isNotEmpty) {
        final batch = _backgroundBatches.removeAt(0);
        _notifyChanged();
        try {
          await saveBatch(batch);
        } catch (error, stackTrace) {
          _visibleFiles.insertAll(0, batch);
          onBackgroundError?.call(error, stackTrace);
        }
        _notifyChanged();
      }
    } finally {
      _backgroundDrain = null;
      if (_backgroundBatches.isNotEmpty) {
        _ensureBackgroundDrain();
      }
    }
  }

  void _notifyChanged() {
    if (!_disposed) onChanged?.call();
  }
}

Iterable<List<T>> chunked<T>(List<T> items, int chunkSize) sync* {
  assert(chunkSize > 0);
  for (var start = 0; start < items.length; start += chunkSize) {
    var end = start + chunkSize;
    if (end > items.length) end = items.length;
    yield items.sublist(start, end);
  }
}
