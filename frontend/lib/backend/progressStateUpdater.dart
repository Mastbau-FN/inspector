import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Aus failedRequestManager.dart holen wir die Konstanten:
import 'package:MBG_Inspektionen/backend/failedRequestManager.dart'
    show sync_in_progress_str, sync_progress_str, sync_success_str;

/// Basisklasse mit dem alten Polling-Mechanismus aus SharedPrefs.
class ProgressStateUpdater extends ChangeNotifier {
  ProgressStateUpdater() {
    _getProgress();
  }

  double? _progress;
  bool? _loading = false;
  bool? _success;

  double? get progress => _progress;
  bool get loading => _loading ?? false;
  bool? get success => _success;

  /// NEU: Setter-Methoden, damit z.B. ein Kind „super.setProgress(...)“ aufrufen kann
  void setProgress(double value) {
    _progress = value;
    notifyListeners();
  }

  void setSuccess(bool value) {
    _success = value;
    notifyListeners();
  }

  // Lese periodisch aus SharedPreferences (alte Logik):
  void _getProgress() async {
    final prefs = await SharedPreferences.getInstance();

    _progress = prefs.getDouble(sync_progress_str);
    _loading = prefs.getBool(sync_in_progress_str);

    final succInt = prefs.getInt(sync_success_str);
    _success = switch (succInt) {
      0 => false,
      1 => true,
      _ => null,
    };

    notifyListeners();

    final delayMs = loading ? 200 : 5000;
    await Future.delayed(Duration(milliseconds: delayMs));
    try {
      _getProgress();
    } catch (e) {
      debugPrint('Error in _getProgress: $e');
    }
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
