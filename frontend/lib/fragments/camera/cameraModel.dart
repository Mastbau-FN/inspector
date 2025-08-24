import 'package:MBG_Inspektionen/helpers/toast.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Hauptklasse zur Verwaltung der Kamerafunktionen
class CameraModel extends ChangeNotifier {
  // Kamera-Controller
  CameraController? _controller;
  CameraController? get controller => _controller;

  // Zoom-Modell
  final ZoomModel _zoomModel = ZoomModel();
  ZoomModel get zoomM => _zoomModel;
  double get zoom => _zoomModel.zoom;

  // Kamera-Index und Status
  int _currentCameraIndex = 0;
  bool _isProcessing = false;
  bool get isProcessing => _isProcessing;

  // Blitzmodus
  FlashMode _flashMode = FlashMode.off;
  FlashMode get flashMode => _flashMode;

  // Letztes aufgenommenes Bild
  XFile? _latestPic;
  XFile? get latestPic => _latestPic;

  // Controller-Erstellung
  Future<CameraController?> get newController async {
    final camera = await currentCamera;
    if (camera == null) return null;

    return CameraController(
      camera,
      ResolutionPreset.max,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
  }

  // Kamera starten
  Future<CameraController> start({bool reuse = true}) async {
    // Vorhandenen Controller wiederverwenden, wenn möglich
    if (reuse && _controller != null && _controller!.value.isInitialized) {
      return _controller!;
    }

    // Neuen Controller erstellen
    _controller = await newController;
    if (_controller == null) {
      throw Exception("Kamerainitialisierung fehlgeschlagen");
    }

    // Controller initialisieren und Blitzmodus setzen
    await _controller!.initialize();
    await _setFlashMode(_flashMode);
    await _getZoomRange();

    // Bildschirm hell halten während die Kamera aktiv ist
    await SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: [SystemUiOverlay.bottom],
    );

    return _controller!;
  }

  // Bild aufnehmen
  Future<XFile> shoot() async {
    if (_isProcessing) {
      throw Exception("Kamera arbeitet noch");
    }

    if (_controller == null || !_controller!.value.isInitialized) {
      debugPrint("Controller nicht initialisiert, starte Kamera...");
      await start();
    }

    try {
      _isProcessing = true;
      notifyListeners();

      // Haptisches Feedback bei Aufnahme
      HapticFeedback.mediumImpact();

      _latestPic = await _controller!.takePicture();

      _isProcessing = false;
      notifyListeners();
      return _latestPic!;
    } catch (e) {
      _isProcessing = false;
      notifyListeners();
      debugPrint("Fehler beim Aufnehmen des Bildes: $e");
      throw Exception("Fehler beim Aufnehmen des Bildes");
    }
  }

  // Bild verwerfen
  void discardPic() {
    debugPrint("Bild verworfen");
    _latestPic = null;
    notifyListeners();
  }

  // Manuelles Setzen des letzten Bilds (für spezielle Anwendungsfälle)
  set latestPic(XFile? value) {
    _latestPic = value;
    notifyListeners();
  }

  // Blitzmodus umschalten
  Future<void> toggleFlash() async {
    final availableFlashModes = [
      FlashMode.off,
      FlashMode.auto,
      FlashMode.always
    ];

    int currentIndex = availableFlashModes.indexOf(_flashMode);
    int nextIndex = (currentIndex + 1) % availableFlashModes.length;
    await setFlashMode(availableFlashModes[nextIndex]);
  }

  // Blitzmodus setzen
  Future<void> setFlashMode(FlashMode mode) async {
    _flashMode = mode;
    await _setFlashMode(mode);
    notifyListeners();
  }

  // Internen Blitzmodus setzen
  Future<void> _setFlashMode(FlashMode mode) async {
    if (_controller != null && _controller!.value.isInitialized) {
      await _controller!.setFlashMode(mode).catchError((e) {
        debugPrint("Fehler beim Setzen des Blitzmodus: $e");
      });
    }
  }

  // Alle verfügbaren Kameras abrufen
  Future<List<CameraDescription>> get allCameras async {
    try {
      final cams = await availableCameras();
      if (cams.isEmpty) {
        throw Exception("Keine Kameras verfügbar");
      }
      return cams;
    } catch (e) {
      showToast("Keine Kamera verfügbar");
      debugPrint(e.toString());
    }
    return [];
  }

  // Hauptkamera abrufen (normalerweise die erste)
  Future<CameraDescription?> get mainCamera async =>
      (await allCameras).firstOrNull;

  // Rückseitige Kamera finden
  Future<CameraDescription?> get backCamera async {
    final cameras = await allCameras;
    return cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );
  }

  // Frontkamera finden
  Future<CameraDescription?> get frontCamera async {
    final cameras = await allCameras;
    return cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );
  }

  // Aktuelle Kamera abrufen
  Future<CameraDescription?> get currentCamera async {
    try {
      return (await allCameras)[_currentCameraIndex];
    } catch (e) {
      debugPrint("Fehler beim Abrufen der aktuellen Kamera: $e");
    }

    return await mainCamera;
  }

  // Zur nächsten Kamera wechseln
  Future<void> nextCamera() async {
    final cameras = await allCameras;
    if (cameras.isEmpty) {
      showToast("Keine Kameras verfügbar");
      return;
    }

    _isProcessing = true;
    notifyListeners();

    _currentCameraIndex = (_currentCameraIndex + 1) % cameras.length;
    _controller = await newController;

    _isProcessing = false;
    notifyListeners();
  }

  // Zur vorherigen Kamera wechseln
  Future<void> prevCamera() async {
    final cameras = await allCameras;
    if (cameras.isEmpty) {
      showToast("Keine Kameras verfügbar");
      return;
    }

    _isProcessing = true;
    notifyListeners();

    _currentCameraIndex =
        (_currentCameraIndex - 1 + cameras.length) % cameras.length;
    _controller = await newController;

    _isProcessing = false;
    notifyListeners();
  }

  // Zoom-Bereich abrufen
  Future<(double, double)> get zoomRange async => await _getZoomRange();

  // Internen Zoom-Bereich abrufen
  Future<(double, double)> _getZoomRange() async {
    _controller ??= await start();
    final maxZoom = await _controller!.getMaxZoomLevel();
    final minZoom = await _controller!.getMinZoomLevel();
    _zoomModel.zoomRange = (minZoom, maxZoom);
    return (minZoom, maxZoom);
  }

  // Zoom setzen
  Future<void> setZoom(double newVal) async {
    _zoomModel.zoom = newVal;
    _controller ??= await start();
    await _controller!.setZoomLevel(newVal);
  }

  // Fokuspunkt setzen
  Future<void> focus(Offset focusPoint) async {
    _controller ??= await start();
    try {
      await _controller!.setFocusPoint(focusPoint);
      await _controller!.setExposurePoint(focusPoint);
    } catch (e) {
      debugPrint("Fehler beim Fokussieren: $e");
    }
  }

  // Automatisch fokussieren
  Future<void> autoFocus() async {
    _controller ??= await start();
    try {
      // In der Mitte fokussieren
      await _controller!.setFocusPoint(const Offset(0.5, 0.5));
      await _controller!.setExposurePoint(const Offset(0.5, 0.5));
    } catch (e) {
      debugPrint("Fehler beim automatischen Fokussieren: $e");
    }
  }

  // Ressourcen freigeben
  @override
  void dispose() {
    disposeCamera();
    // Bildschirmeinstellungen wiederherstellen
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
        overlays: SystemUiOverlay.values);
    super.dispose();
  }

  // Kamera-Ressourcen freigeben
  void disposeCamera() {
    if (_controller != null) {
      _controller!.setFlashMode(FlashMode.off).catchError((e) {
        debugPrint("Fehler beim Ausschalten des Blitzes: $e");
      });
      _controller!.dispose();
      _controller = null;
    }
  }
}

/// Modell zur Verwaltung der Zoom-Funktionalität
class ZoomModel extends ChangeNotifier {
  // Standard-Zoom-Bereich
  (double, double) _zoomRange = (1.0, 2.0);

  // Aktueller Zoom-Wert
  double _zoom = 1.0;

  // Getter und Setter
  double get zoom => _zoom;
  (double, double) get zoomRange => _zoomRange;

  set zoom(double newVal) {
    _zoom = newVal;
    debugPrint("Zoom: $newVal");
    notifyListeners();
  }

  set zoomRange((double, double) range) {
    _zoomRange = range;
    notifyListeners();
  }
}

/// Hilfserweiterung für die Konvertierung von Tupeln zu RangeValues
extension ToRangeValues on (double, double) {
  RangeValues toRangeValues() => RangeValues(this.$1, this.$2);
}

/// Erweiterung für FlashMode, um Icons und Text zu erhalten
extension FlashModeExtension on FlashMode {
  IconData get icon => switch (this) {
        FlashMode.off => Icons.flash_off,
        FlashMode.auto => Icons.flash_auto,
        FlashMode.always => Icons.flash_on,
        FlashMode.torch => Icons.highlight,
      };

  String get label => switch (this) {
        FlashMode.off => 'Aus',
        FlashMode.auto => 'Auto',
        FlashMode.always => 'An',
        FlashMode.torch => 'Licht',
      };
}
