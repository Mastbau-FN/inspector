import 'dart:async';
import 'dart:io';

import 'package:MBG_Inspektionen/helpers/toast.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Serialisiert schnell aufeinanderfolgende Plattformaufrufe und verwirft
/// dabei Zwischenwerte. Das ist insbesondere fuer Pinch-/Slider-Gesten
/// wichtig, die mehrere Werte pro Frame liefern koennen.
@visibleForTesting
class LatestAsyncValueQueue<T> {
  LatestAsyncValueQueue(this._apply);

  final Future<void> Function(T value) _apply;
  T? _pendingValue;
  bool _hasPendingValue = false;
  bool _closed = false;
  Future<void>? _running;

  Future<void> add(T value) {
    if (_closed) return Future<void>.value();
    _pendingValue = value;
    _hasPendingValue = true;
    return _running ??= _drain();
  }

  Future<void> waitForIdle() async {
    while (true) {
      final running = _running;
      if (running == null) return;
      await running;
    }
  }

  void clearPending() {
    _pendingValue = null;
    _hasPendingValue = false;
  }

  void close() {
    _closed = true;
    clearPending();
  }

  Future<void> _drain() async {
    try {
      while (!_closed && _hasPendingValue) {
        final value = _pendingValue as T;
        _pendingValue = null;
        _hasPendingValue = false;
        await _apply(value);
      }
    } finally {
      _running = null;
      // Ein Wert kann genau zwischen der letzten Schleifenpruefung und dem
      // Abschluss des Futures eingetroffen sein.
      if (!_closed && _hasPendingValue) {
        await add(_pendingValue as T);
      }
    }
  }
}

/// Hauptklasse zur Verwaltung der Kamerafunktionen
class CameraModel extends ChangeNotifier {
  static bool _staleCaptureCleanupStarted = false;

  CameraModel() {
    _zoomQueue = LatestAsyncValueQueue<double>(_applyZoomLevel);
    _focusQueue = LatestAsyncValueQueue<Offset>(_applyFocusPoint);
    if (!_staleCaptureCleanupStarted) {
      _staleCaptureCleanupStarted = true;
      unawaited(_cleanupStaleCameraCaptures());
    }
  }

  // Kamera-Controller
  CameraController? _controller;
  CameraController? get controller => _controller;
  Future<CameraController>? _controllerFuture;
  Future<List<CameraDescription>>? _availableCamerasFuture;
  int _controllerGeneration = 0;
  bool _disposed = false;

  // Zoom-Modell
  final ZoomModel _zoomModel = ZoomModel();
  ZoomModel get zoomM => _zoomModel;
  double get zoom => _zoomModel.zoom;
  late final LatestAsyncValueQueue<double> _zoomQueue;
  late final LatestAsyncValueQueue<Offset> _focusQueue;
  Offset _lastFocusPoint = const Offset(0.5, 0.5);
  int _zoomRevision = 0;
  int _focusedZoomRevision = 0;

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
  final Set<ImageProvider> _latestPicturePreviewProviders = <ImageProvider>{};

  CameraController _createController(CameraDescription camera) {
    return CameraController(
      camera,
      // `max` can select 40-50 MP sensors on current Android devices. A 4K
      // inspection photo retains detail while avoiding very large camera and
      // preview buffers after many consecutive shots.
      ResolutionPreset.ultraHigh,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
  }

  // Kamera starten
  Future<CameraController> start({bool reuse = true}) {
    if (_disposed) {
      return Future.error(StateError('CameraModel wurde bereits geschlossen'));
    }

    if (reuse) {
      final existingFuture = _controllerFuture;
      if (existingFuture != null) return existingFuture;
      final existingController = _controller;
      if (existingController != null &&
          existingController.value.isInitialized) {
        return _controllerFuture = Future.value(existingController);
      }
    }

    final generation = ++_controllerGeneration;
    final future = _startNewController(generation);
    _controllerFuture = future;
    unawaited(future.then<void>((_) {}, onError: (Object _, StackTrace __) {
      if (identical(_controllerFuture, future)) {
        _controllerFuture = null;
      }
    }));
    return future;
  }

  Future<CameraController> _startNewController(int generation) async {
    final camera = await currentCamera;
    if (camera == null) {
      throw Exception('Kamerainitialisierung fehlgeschlagen');
    }

    final previous = _controller;
    _controller = null;
    if (previous != null) {
      try {
        await previous.setFlashMode(FlashMode.off);
      } catch (_) {}
      await previous.dispose();
    }

    if (_disposed || generation != _controllerGeneration) {
      throw StateError('CameraModel wurde bereits geschlossen');
    }

    final next = _createController(camera);
    _controller = next;
    try {
      await next.initialize();
      if (_disposed || generation != _controllerGeneration) {
        throw StateError('CameraModel wurde während des Starts geschlossen');
      }
      await next.setFlashMode(_flashMode).catchError((e) {
        debugPrint('Fehler beim Setzen des Blitzmodus: $e');
      });
      await _updateZoomRange(next, generation: generation);
      // CameraX initializes a fresh controller with a valid autofocus state.
      // Only a later user zoom needs an additional focus/exposure cycle.
      _focusedZoomRevision = _zoomRevision;

      // Bildschirm hell halten während die Kamera aktiv ist
      await SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: [SystemUiOverlay.bottom],
      );
      return next;
    } catch (_) {
      if (identical(_controller, next)) _controller = null;
      try {
        await next.dispose();
      } catch (_) {}
      rethrow;
    }
  }

  Future<(double, double)> _updateZoomRange(
    CameraController controller, {
    int? generation,
  }) async {
    final maxZoom = await controller.getMaxZoomLevel();
    final minZoom = await controller.getMinZoomLevel();
    if (_disposed ||
        (generation != null && generation != _controllerGeneration)) {
      throw StateError('CameraModel wurde während des Starts geschlossen');
    }
    _zoomModel.zoomRange = (minZoom, maxZoom);
    final restoredZoom = _zoomModel.zoom.clamp(minZoom, maxZoom).toDouble();
    _zoomModel.zoom = restoredZoom;
    if (restoredZoom != minZoom) {
      await controller.setZoomLevel(restoredZoom);
    }
    return (minZoom, maxZoom);
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

      // Pinch und Slider liefern sehr viele Werte. Vor dem Ausloesen muss der
      // letzte native Zoomwert gesetzt sein. Anschliessend fokussieren und
      // belichten wir erneut, weil ein Zoom (insbesondere ein Objektivwechsel
      // durch CameraX) den zuvor bestimmten Fokus ungueltig machen kann.
      await _zoomQueue.waitForIdle();
      await refocusAfterZoom();

      final activeController = _controller!;

      // Haptisches Feedback erst unmittelbar zur tatsaechlichen Aufnahme.
      HapticFeedback.mediumImpact();
      _latestPic = await activeController.takePicture();

      // The capture preview replaces the live preview. Release camera buffers
      // before decoding the captured photo; retaining both at once caused a
      // reproducible ~100 MB RSS spike on the test device.
      try {
        await disposeCamera();
      } catch (e) {
        debugPrint('Fehler beim Freigeben der Kamera nach Aufnahme: $e');
      }

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
  void discardPic({bool deleteTemporaryFile = true}) {
    debugPrint("Bild verworfen");
    final discarded = _latestPic;
    _evictLatestPicturePreview();
    _latestPic = null;
    if (deleteTemporaryFile && discarded != null) {
      unawaited(_deleteTemporaryCapture(discarded));
    }
    notifyListeners();
  }

  Future<void> _deleteTemporaryCapture(XFile file) async {
    try {
      final cachePath = (await getTemporaryDirectory()).absolute.path;
      final source = File(file.path).absolute;
      final cachePrefix = '$cachePath${Platform.pathSeparator}';
      if (source.path.startsWith(cachePrefix) && await source.exists()) {
        await source.delete();
      }
    } catch (_) {}
  }

  Future<void> _cleanupStaleCameraCaptures() async {
    var matchingFiles = 0;
    var removedFiles = 0;
    var releasedBytes = 0;
    try {
      final cache = await getTemporaryDirectory();
      final cutoff = DateTime.now().subtract(const Duration(days: 1));
      await for (final entity in cache.list(followLinks: false)) {
        if (entity is! File) continue;
        final name = entity.path.split(Platform.pathSeparator).last;
        if (!RegExp(r'^CAP\d+\.jpe?g$', caseSensitive: false).hasMatch(name)) {
          continue;
        }
        matchingFiles++;
        try {
          final stat = await entity.stat();
          if (!stat.modified.isBefore(cutoff)) continue;
          await entity.delete();
          removedFiles++;
          releasedBytes += stat.size;
        } catch (e) {
          debugPrint('Alte Kamera-Temporärdatei konnte nicht gelöscht werden: '
              '${entity.path}: $e');
        }
      }
      debugPrint('Kamera-Cache geprüft: $matchingFiles Dateien, '
          '$removedFiles entfernt, '
          '${(releasedBytes / (1024 * 1024)).toStringAsFixed(1)} MB');
    } catch (e) {
      debugPrint('Kamera-Cache konnte nicht geprüft werden: $e');
    }
  }

  void _evictLatestPicturePreview() {
    final latest = _latestPic;
    final providers = <ImageProvider>{
      ..._latestPicturePreviewProviders,
      if (latest != null) FileImage(File(latest.path)),
    };
    for (final provider in providers) {
      unawaited(provider.evict());
    }
    _latestPicturePreviewProviders.clear();

    // discardPic is called while the preview widget still has a live listener.
    // Evict once more after that widget has left the tree so the decoded
    // ui.Image can actually be disposed.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final provider in providers) {
        unawaited(provider.evict());
      }
    });
  }

  ImageProvider latestPicturePreviewProvider({
    required int cacheWidth,
    required int cacheHeight,
  }) {
    final latest = _latestPic;
    if (latest == null) {
      throw StateError('Kein aufgenommenes Bild für die Vorschau vorhanden');
    }
    final provider = ResizeImage.resizeIfNeeded(
      cacheWidth,
      cacheHeight,
      FileImage(File(latest.path)),
    );
    _latestPicturePreviewProviders.add(provider);
    return provider;
  }

  // Manuelles Setzen des letzten Bilds (für spezielle Anwendungsfälle)
  set latestPic(XFile? value) {
    if (_latestPic?.path != value?.path) _evictLatestPicturePreview();
    _latestPic = value;
    if (value != null) {
      // Queue review also replaces the live preview. Avoid retaining camera
      // buffers behind a previously captured image.
      unawaited(disposeCamera());
    }
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
  Future<List<CameraDescription>> get allCameras {
    return _availableCamerasFuture ??= _loadCameras();
  }

  Future<List<CameraDescription>> _loadCameras() async {
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
    await _switchCamera(1);
  }

  // Zur vorherigen Kamera wechseln
  Future<void> prevCamera() async {
    await _switchCamera(-1);
  }

  Future<void> _switchCamera(int delta) async {
    if (_isProcessing || _disposed) return;
    final cameras = await allCameras;
    if (cameras.isEmpty) {
      showToast("Keine Kameras verfügbar");
      return;
    }

    _isProcessing = true;
    notifyListeners();

    try {
      final inFlight = _controllerFuture;
      if (inFlight != null) {
        try {
          await inFlight;
        } catch (_) {}
      }
      _currentCameraIndex =
          (_currentCameraIndex + delta + cameras.length) % cameras.length;
      await start(reuse: false);
    } finally {
      _isProcessing = false;
      if (!_disposed) notifyListeners();
    }
  }

  // Zoom-Bereich abrufen
  Future<(double, double)> get zoomRange async => await _getZoomRange();

  // Internen Zoom-Bereich abrufen
  Future<(double, double)> _getZoomRange() async {
    await start();
    return _zoomModel.zoomRange;
  }

  // Zoom setzen
  Future<void> setZoom(double newVal) {
    if (_disposed) return Future<void>.value();
    final range = _zoomModel.zoomRange;
    final clampedZoom = newVal.clamp(range.$1, range.$2).toDouble();
    if (clampedZoom != _zoomModel.zoom) {
      _zoomRevision++;
    }
    _zoomModel.zoom = clampedZoom;
    return _zoomQueue.add(clampedZoom);
  }

  Future<void> _applyZoomLevel(double zoom) async {
    if (_disposed) return;
    try {
      final controller = await start();
      if (_disposed || !identical(controller, _controller)) return;
      await controller.setZoomLevel(zoom);
    } catch (e) {
      if (!_disposed) debugPrint('Fehler beim Setzen des Zooms: $e');
    }
  }

  // Fokuspunkt setzen
  Future<void> focus(Offset focusPoint) {
    if (_disposed) return Future<void>.value();
    _lastFocusPoint = Offset(
      focusPoint.dx.clamp(0.0, 1.0).toDouble(),
      focusPoint.dy.clamp(0.0, 1.0).toDouble(),
    );
    return _focusQueue.add(_lastFocusPoint);
  }

  Future<void> _applyFocusPoint(Offset focusPoint) async {
    if (_disposed) return;
    try {
      // Ein noch laufender Zoom darf den gerade gesetzten Fokus nicht sofort
      // wieder entwerten.
      await _zoomQueue.waitForIdle();
      final zoomRevision = _zoomRevision;
      final controller = await start();
      if (_disposed || !identical(controller, _controller)) return;
      try {
        await controller.setFocusMode(FocusMode.auto);
      } catch (e) {
        debugPrint('Automatischer Fokusmodus wird nicht unterstuetzt: $e');
      }
      await controller.setFocusPoint(focusPoint);
      await controller.setExposurePoint(focusPoint);
      if (_zoomRevision == zoomRevision) {
        _focusedZoomRevision = zoomRevision;
      }
    } catch (e) {
      if (!_disposed) debugPrint('Fehler beim Fokussieren: $e');
    }
  }

  /// Wartet auf den letzten Zoomwert und fokussiert danach erneut. Wird am
  /// Ende einer Zoomgeste und unmittelbar vor jeder Aufnahme verwendet.
  Future<void> refocusAfterZoom() async {
    if (_disposed) return;
    await _zoomQueue.waitForIdle();
    if (_disposed) return;
    // onChangeEnd already refocuses after a slider/pinch gesture. The capture
    // path used to repeat all three CameraX focus calls unconditionally,
    // adding several seconds on the Motorola test device.
    await _focusQueue.waitForIdle();
    if (_disposed || _focusedZoomRevision == _zoomRevision) return;
    await _focusQueue.add(_lastFocusPoint);
  }

  // Automatisch fokussieren
  Future<void> autoFocus() => focus(const Offset(0.5, 0.5));

  // Ressourcen freigeben
  @override
  void dispose() {
    _disposed = true;
    _zoomQueue.close();
    _focusQueue.close();
    final discarded = _latestPic;
    _evictLatestPicturePreview();
    if (discarded != null) unawaited(_deleteTemporaryCapture(discarded));
    unawaited(disposeCamera());
    _zoomModel.dispose();
    // Bildschirmeinstellungen wiederherstellen
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
        overlays: SystemUiOverlay.values);
    super.dispose();
  }

  // Kamera-Ressourcen freigeben
  Future<void> disposeCamera() async {
    _controllerGeneration++;
    _controllerFuture = null;
    _zoomQueue.clearPending();
    _focusQueue.clearPending();
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      await controller.setFlashMode(FlashMode.off).catchError((e) {
        debugPrint("Fehler beim Ausschalten des Blitzes: $e");
      });
      await controller.dispose();
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
    if (_zoom == newVal) return;
    _zoom = newVal;
    debugPrint("Zoom: $newVal");
    notifyListeners();
  }

  set zoomRange((double, double) range) {
    if (_zoomRange == range) return;
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
