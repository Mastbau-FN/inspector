import 'dart:async';

import 'package:flutter/foundation.dart';

class DownloadProgressState {
  final int totalTasks;
  final int doneTasks;
  final String currentLabel;
  final double fraction; // monotonic [0..1]
  final int stepIndex; // 1-based
  final int stepCount;

  const DownloadProgressState({
    required this.totalTasks,
    required this.doneTasks,
    required this.currentLabel,
    required this.fraction,
    required this.stepIndex,
    required this.stepCount,
  });

  int get percent => (fraction * 100).clamp(0, 100).round();
}

class InspectionDownloadSteps {
  static const int count = 6;
  static const int refresh = 1;
  static const int categories = 2;
  static const int checkpoints = 3;
  static const int defects = 4;
  static const int photos = 5;
  static const int documents = 6;

  static const String refreshLabel = 'Inspektionsdaten aktualisieren';
  static const String categoriesLabel = 'Prüfkategorien laden';
  static const String checkpointsLabel = 'Prüfpunkte laden';
  static const String defectsLabel = 'Mängel und Mängelfrei-Einträge laden';
  static const String photosLabel = 'Fotos speichern';
  static const String noPhotosLabel = 'Keine Fotos zu speichern';
  static const String documentsPrepareLabel = 'Dokumente herunterladen';
  static const String noDocumentsLabel = 'Keine Dokumente vorhanden';

  static String documentCheckLabel(int current, int total) =>
      'Dokumente prüfen ($current/$total)';
  static String documentLabel(int current, int total) =>
      'Dokumente speichern ($current/$total)';
}

class DownloadTaskToken {
  final int id;
  final int step;
  const DownloadTaskToken(this.id, this.step);
}

class DownloadProgressSession {
  final ValueNotifier<DownloadProgressState> notifier;

  int _nextId = 1;
  Future<void> _serialDownloadTail = Future<void>.value();
  final int _stepCount;
  int _currentStep = 0;
  final Map<int, int> _totalByStep = <int, int>{};
  final Map<int, int> _doneByStep = <int, int>{};
  final Set<int> _finishedSteps = <int>{};
  bool _finished = false;
  final Map<String, DownloadTaskToken> _reservedByKey =
      <String, DownloadTaskToken>{};
  final Set<int> _completedTaskIds = <int>{};

  DownloadProgressSession({String initialLabel = '', int stepCount = 3})
      : _stepCount = stepCount,
        notifier = ValueNotifier<DownloadProgressState>(
          DownloadProgressState(
            totalTasks: 0,
            doneTasks: 0,
            currentLabel: initialLabel,
            fraction: 0.0,
            stepIndex: 0,
            stepCount: stepCount,
          ),
        );

  void setStep(int stepIndex, {String? label}) {
    final next = stepIndex.clamp(0, _stepCount);
    if (next < _currentStep) return;
    if (next > _currentStep) {
      for (int s = _currentStep; s < next; s++) {
        _finishedSteps.add(s);
      }
    }
    _currentStep = next;
    _emit(currentLabel: label);
  }

  DownloadTaskToken reserveTask(
    String key, {
    required int step,
    String label = '',
  }) {
    final existing = _reservedByKey[key];
    if (existing != null) {
      if (label.isNotEmpty) _emit(currentLabel: label);
      return existing;
    }
    final stepIndex = step.clamp(0, _stepCount);
    _totalByStep[stepIndex] = (_totalByStep[stepIndex] ?? 0) + 1;
    final token = DownloadTaskToken(_nextId++, stepIndex);
    _reservedByKey[key] = token;
    _emit(currentLabel: label.isEmpty ? null : label);
    return token;
  }

  DownloadTaskToken beginTask(
    String label, {
    String? key,
    required int step,
  }) {
    final stepIndex = step.clamp(0, _stepCount);
    if (key != null) {
      final reserved = _reservedByKey[key];
      if (reserved != null) {
        _emit(currentLabel: label.isEmpty ? null : label);
        return reserved;
      }
    }

    _totalByStep[stepIndex] = (_totalByStep[stepIndex] ?? 0) + 1;
    _emit(currentLabel: label.isEmpty ? null : label);
    final token = DownloadTaskToken(_nextId++, stepIndex);
    if (key != null) {
      _reservedByKey[key] = token;
    }
    return token;
  }

  void endTask(DownloadTaskToken token, {required bool success}) {
    if (!_completedTaskIds.add(token.id)) return;
    final stepIndex = token.step.clamp(0, _stepCount);
    _doneByStep[stepIndex] = (_doneByStep[stepIndex] ?? 0) + 1;
    _emit();
  }

  Future<T> enqueueDownload<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _serialDownloadTail = _serialDownloadTail.catchError((_) {}).then(
      (_) async {
        try {
          completer.complete(await action());
        } catch (error, stackTrace) {
          completer.completeError(error, stackTrace);
        }
      },
    );
    return completer.future;
  }

  void markFinished() {
    _finished = true;
    for (int s = 0; s <= _stepCount; s++) {
      _finishedSteps.add(s);
    }
    _emit();
  }

  void _emit({String? currentLabel}) {
    final total = _totalByStep[_currentStep] ?? 0;
    final done = _doneByStep[_currentStep] ?? 0;
    final isStepFinished = _finishedSteps.contains(_currentStep) || _finished;

    var raw = total == 0
        ? (isStepFinished ? 1.0 : 0.0)
        : (done / total).clamp(0.0, 1.0);
    if (total > 0 && done >= total && !isStepFinished) {
      raw = done / (total + 1);
    }
    notifier.value = DownloadProgressState(
      totalTasks: total,
      doneTasks: done,
      currentLabel: currentLabel ?? notifier.value.currentLabel,
      fraction: raw.clamp(0.0, 1.0),
      stepIndex: _currentStep,
      stepCount: _stepCount,
    );
  }

  void dispose() {
    notifier.dispose();
  }
}

class DownloadProgress {
  static final DownloadProgress instance = DownloadProgress._internal();
  DownloadProgress._internal();

  final ValueNotifier<int> revision = ValueNotifier<int>(0);
  DownloadProgressSession? _active;
  DownloadProgressSession? _lastFinished;
  String? _activeKey;
  DownloadProgressSession? get active => _active;
  String? get activeKey => _activeKey;

  DownloadProgressSession? activeFor(String key) {
    if (_activeKey != key) return null;
    return _active;
  }

  DownloadProgressSession start({
    String label = '',
    int stepCount = 3,
    String? key,
  }) {
    final active = _active;
    if (key != null && active != null && _activeKey == key) {
      return active;
    }
    _lastFinished?.dispose();
    _lastFinished = null;
    _active?.dispose();
    final session = DownloadProgressSession(
      initialLabel: label,
      stepCount: stepCount,
    );
    _active = session;
    _activeKey = key;
    revision.value++;
    return session;
  }

  void finish(DownloadProgressSession session) {
    if (!identical(_active, session)) return;
    session.markFinished();
    _active = null;
    _activeKey = null;
    _lastFinished = session;
    revision.value++;
    // Keep the finished notifier alive until the next download replaces it.
  }
}
