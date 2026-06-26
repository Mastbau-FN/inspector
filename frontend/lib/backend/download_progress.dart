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

class DownloadTaskToken {
  final int id;
  final int step;
  const DownloadTaskToken(this.id, this.step);
}

class DownloadProgressSession {
  final ValueNotifier<DownloadProgressState> notifier;

  int _nextId = 1;
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
    _emit(currentLabel: label);
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
        _emit(currentLabel: label);
        return reserved;
      }
    }

    _totalByStep[stepIndex] = (_totalByStep[stepIndex] ?? 0) + 1;
    _emit(currentLabel: label);
    return DownloadTaskToken(_nextId++, stepIndex);
  }

  void endTask(DownloadTaskToken token, {required bool success}) {
    if (!_completedTaskIds.add(token.id)) return;
    final stepIndex = token.step.clamp(0, _stepCount);
    _doneByStep[stepIndex] = (_doneByStep[stepIndex] ?? 0) + 1;
    _emit();
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

    final denom = isStepFinished
        ? (total == 0 ? 1 : total)
        : (total > (done + 1) ? total : (done + 1));
    final raw = denom == 0 ? 0.0 : (done / denom);
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

  DownloadProgressSession? _active;
  DownloadProgressSession? get active => _active;

  DownloadProgressSession start({String label = ''}) {
    _active?.dispose();
    final session = DownloadProgressSession(initialLabel: label);
    _active = session;
    return session;
  }

  void finish(DownloadProgressSession session) {
    if (!identical(_active, session)) return;
    session.markFinished();
    _active = null;
    // session is disposed by the UI owner.
  }
}
