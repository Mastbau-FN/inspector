import 'package:flutter/foundation.dart';

class DownloadProgressState {
  final int totalTasks;
  final int doneTasks;
  final String currentLabel;
  final double fraction; // monotonic [0..1]

  const DownloadProgressState({
    required this.totalTasks,
    required this.doneTasks,
    required this.currentLabel,
    required this.fraction,
  });

  int get percent => (fraction * 100).clamp(0, 100).round();
}

class DownloadTaskToken {
  final int id;
  const DownloadTaskToken(this.id);
}

class DownloadProgressSession {
  final ValueNotifier<DownloadProgressState> notifier;

  int _nextId = 1;
  int _total = 0;
  int _done = 0;
  bool _finished = false;
  final Map<String, DownloadTaskToken> _reservedByKey =
      <String, DownloadTaskToken>{};
  final Set<int> _completedTaskIds = <int>{};

  DownloadProgressSession({String initialLabel = ''})
      : notifier = ValueNotifier<DownloadProgressState>(
          DownloadProgressState(
            totalTasks: 0,
            doneTasks: 0,
            currentLabel: initialLabel,
            fraction: 0.0,
          ),
        );

  DownloadTaskToken reserveTask(String key, {String label = ''}) {
    final existing = _reservedByKey[key];
    if (existing != null) {
      if (label.isNotEmpty) _emit(currentLabel: label);
      return existing;
    }
    _total += 1;
    final token = DownloadTaskToken(_nextId++);
    _reservedByKey[key] = token;
    _emit(currentLabel: label);
    return token;
  }

  DownloadTaskToken beginTask(String label, {String? key}) {
    if (key != null) {
      final reserved = _reservedByKey[key];
      if (reserved != null) {
        _emit(currentLabel: label);
        return reserved;
      }
    }

    _total += 1;
    _emit(currentLabel: label);
    return DownloadTaskToken(_nextId++);
  }

  void endTask(DownloadTaskToken token, {required bool success}) {
    if (!_completedTaskIds.add(token.id)) return;
    _done = (_done + 1).clamp(0, _total);
    _emit();
  }

  void markFinished() {
    _finished = true;
    _emit();
  }

  void _emit({String? currentLabel}) {
    final denom = _finished
        ? (_total == 0 ? 1 : _total)
        : (_total > (_done + 1) ? _total : (_done + 1));
    final raw = denom == 0 ? 0.0 : (_done / denom);
    notifier.value = DownloadProgressState(
      totalTasks: _total,
      doneTasks: _done,
      currentLabel: currentLabel ?? notifier.value.currentLabel,
      fraction: raw.clamp(0.0, 1.0),
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
