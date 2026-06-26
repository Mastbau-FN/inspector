import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Aus failedRequestManager.dart holen wir die Konstanten:
import 'package:MBG_Inspektionen/backend/failedRequestManager.dart'
    show sync_in_progress_str, sync_progress_str, sync_success_str;

/// Basisklasse mit dem alten Polling-Mechanismus aus SharedPrefs.
class ProgressStateUpdater extends ChangeNotifier {
  ProgressStateUpdater() {
    _poll();
  }

  double? _progress;
  bool? _loading = false;
  bool? _success;
  bool _disposed = false;
  Timer? _timer;

  double? get progress => _progress;
  bool get loading => _loading ?? false;
  bool? get success => _success;

  /// NEU: Setter-Methoden, damit z.B. ein Kind „super.setProgress(...)“ aufrufen kann
  void setProgress(double value) {
    if (_disposed) return;
    _progress = value;
    notifyListeners();
  }

  void setSuccess(bool value) {
    if (_disposed) return;
    _success = value;
    notifyListeners();
  }

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  // Lese periodisch aus SharedPreferences (alte Logik):
  Future<void> _poll() async {
    if (_disposed) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_disposed) return;

      _progress = prefs.getDouble(sync_progress_str);
      _loading = prefs.getBool(sync_in_progress_str);

      final succInt = prefs.getInt(sync_success_str);
      _success = switch (succInt) {
        0 => false,
        1 => true,
        _ => null,
      };

      if (!_disposed) notifyListeners();
    } catch (e) {
      debugPrint('Error in _poll: $e');
    } finally {
      if (_disposed) return;
      final delayMs = loading ? 200 : 5000;
      _timer?.cancel();
      _timer = Timer(Duration(milliseconds: delayMs), () {
        _poll();
      });
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }
}

/// Abgeleitete Klasse, um zusätzliche Infos (aktuelle Inspektion, ETA etc.) zu speichern.
class ExtendedProgressStateUpdater extends ProgressStateUpdater {
  String? _currentInspection;
  double? _currentInspectionProgress;
  String? _eta;

  String? get currentInspection => _currentInspection;
  double? get currentInspectionProgress => _currentInspectionProgress;
  String? get eta => _eta;

  /// Wird von unserem onProgress(...) aufgerufen.
  void setDetailedProgress({
    required double overallProgress,
    required bool? success, // kann null sein, wenn gerade erst Zwischenschritt
    required String? inspectionId,
    required double inspProgress,
    required String etaString,
  }) {
    // Verwende die neu definierten Methoden in der Basisklasse
    super.setProgress(overallProgress);
    if (success != null) {
      super.setSuccess(success);
    }
    _currentInspection = inspectionId;
    _currentInspectionProgress = inspProgress;
    _eta = etaString;
    notifyListeners();
  }
}
