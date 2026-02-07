import 'package:MBG_Inspektionen/fragments/camera/cameraModel.dart';
import 'package:MBG_Inspektionen/fragments/loadingscreen/loadingView.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import '../../../widgets/error.dart';

/// Hauptkomponente für die Kameravorschau mit optionalen Steuerelementen
class CameraPreviewOnly extends StatelessWidget {
  final List<Widget> children;

  const CameraPreviewOnly({this.children = const [], Key? key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black,
      child: SafeArea(
        child: Consumer<CameraModel>(
          builder: (context, model, _) {
            return FutureBuilder(
              future: model.start(),
              builder: (context, AsyncSnapshot<CameraController> snapshot) {
                return switch ((snapshot.connectionState, snapshot.data)) {
                  (ConnectionState.done, CameraController cc) =>
                    _buildCameraPreview(cc, model, context),
                  (ConnectionState.done, null) => Center(
                      child: ErrorText("Keine Kamera verfügbar"),
                    ),
                  (ConnectionState.waiting, _) =>
                    const Center(child: LoadingView()),
                  (ConnectionState.active, _) =>
                    const Center(child: LoadingView()),
                  (ConnectionState.none, _) => Center(
                      child: ErrorText("Keine Kamera verfügbar"),
                    ),
                };
              },
            );
          },
        ),
      ),
    );
  }

  /// Baut die Kameravorschau mit allen notwendigen Elementen
  Widget _buildCameraPreview(
      CameraController controller, CameraModel model, BuildContext context) {
    // Bildschirmabmessungen für responsives Design
    final Size screenSize = MediaQuery.of(context).size;

    return Container(
      color: Colors.black,
      width: screenSize.width,
      height: screenSize.height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Kamera mit Interaktionshandler
          CameraInteractionHandler(
            model: model,
            controller: controller,
          ),

          // Zusätzliche Steuerelemente (falls vorhanden)
          if (children.isNotEmpty)
            Positioned(
              top: 16,
              right: 16,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: children,
              ),
            ),

          // Kamera-Wechsel-Hinweis
          Positioned(
            bottom: 16,
            right: 16,
            child: _buildCameraSwitchIndicator(),
          ),

          // Ladeindikator (wenn die Kamera verarbeitet)
          if (model.isProcessing)
            const Center(
              child: CircularProgressIndicator(
                color: Colors.white,
              ),
            ),
        ],
      ),
    );
  }

  /// Hinweis zum Kamerawechsel
  Widget _buildCameraSwitchIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.flip_camera_ios, color: Colors.white, size: 16),
          SizedBox(width: 4),
          Text(
            'Doppeltipp',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

/// Komponente für Kamera-Interaktionen (Zoom, Fokus, Kamerawechsel)
class CameraInteractionHandler extends StatefulWidget {
  final CameraModel model;
  final CameraController controller;

  const CameraInteractionHandler({
    Key? key,
    required this.model,
    required this.controller,
  }) : super(key: key);

  @override
  State<CameraInteractionHandler> createState() =>
      _CameraInteractionHandlerState();
}

class _CameraInteractionHandlerState extends State<CameraInteractionHandler>
    with SingleTickerProviderStateMixin {
  double _startZoom = 1.0;
  Offset? _focusPoint;
  late AnimationController _focusAnimationController;
  static const EventChannel _volumeButtonChannel =
      EventChannel('volume_button_events');

  @override
  void initState() {
    super.initState();
    _initVolumeButtonHandler();

    // Animation für das Fokusquadrat
    _focusAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
  }

  @override
  void dispose() {
    _focusAnimationController.dispose();
    super.dispose();
  }

  /// Initialisiert den Event-Listener für die Lautstärketasten
  void _initVolumeButtonHandler() {
    _volumeButtonChannel.receiveBroadcastStream().listen((event) {
      if (event == "volume_up") {
        _adjustZoom(0.1); // Zoom erhöhen
      } else if (event == "volume_down") {
        _adjustZoom(-0.1); // Zoom verringern
      }
    }, onError: (error) {
      debugPrint("Fehler beim Empfang von Lautstärketasten-Events: $error");
    });
  }

  /// Passt den Zoom basierend auf dem angegebenen Schritt an
  void _adjustZoom(double zoomStep) async {
    double newZoom = (widget.model.zoom + zoomStep).clamp(
        widget.model.zoomM.zoomRange.$1, widget.model.zoomM.zoomRange.$2);
    await widget.model.setZoom(newZoom);
  }

  /// Zeigt kurz den Fokuspunkt an und blendet ihn dann aus
  void _showFocusPoint(Offset point) {
    setState(() {
      _focusPoint = point;
    });

    _focusAnimationController.forward(from: 0.0);
    Future.delayed(const Duration(milliseconds: 800)).then((_) {
      if (mounted) {
        _focusAnimationController.reverse().then((_) {
          if (mounted) {
            setState(() => _focusPoint = null);
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Zoom-Gesten
      onScaleStart: (details) {
        _startZoom = widget.model.zoom;
      },
      onScaleUpdate: (details) {
        double newZoom = (_startZoom * details.scale).clamp(
            widget.model.zoomM.zoomRange.$1, widget.model.zoomM.zoomRange.$2);
        widget.model.setZoom(newZoom);
      },

      // Fokus-Gesten
      onTapDown: (details) {
        _showFocusPoint(details.localPosition);

        final RenderBox? box = context.findRenderObject() as RenderBox?;
        if (box == null || box.size.isEmpty) return;

        final Offset normalizedFocusPoint = Offset(
          details.localPosition.dx / box.size.width,
          details.localPosition.dy / box.size.height,
        );
        widget.model.focus(normalizedFocusPoint);
      },

      // Kamerawechsel per Doppeltipp
      onDoubleTap: () async {
        HapticFeedback.mediumImpact(); // Haptisches Feedback beim Kamerawechsel
        await widget.model.nextCamera();
      },

      // Kameravorschau und UI-Elemente
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Kameravorschau mit korrekter Ausrichtung
          _buildCameraPreview(),

          // Fokusquadrat (wenn ein Fokuspunkt gesetzt wurde)
          if (_focusPoint != null) _buildFocusPoint(),
        ],
      ),
    );
  }

  /// Baut die Kameravorschau mit korrekter Ausrichtung
  Widget _buildCameraPreview() {
    // Holen der Geräte-Orientierung (Portrait/Landscape)
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    // Rotation für Hoch- und Querformat
    final shouldRotate = !isLandscape;
    // Im Hochformat um 90° drehen, im Querformat keine Drehung
    final double rotationAngle = shouldRotate ? pi / 2 : pi / 2;

    // Bildschirmgröße ermitteln
    final screenSize = MediaQuery.of(context).size;

    // So wird das Seitenverhältnis GARANTIERT 3:4 im Hochformat
    double width, height;
    if (isLandscape) {
      // Im Querformat: 4:3
      height = screenSize.height * 0.9;
      width = height * 4 / 3;
    } else {
      // Im Hochformat: 3:4
      width = screenSize.width * 0.9;
      height = width * 4 / 3;
    }

    return Container(
      color: Colors.black,
      child: Center(
        child: Container(
          // FESTE Größe für die Vorschau, damit das Verhältnis GARANTIERT stimmt
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: Colors.black,
          ),
          child: ClipRect(
            child: Transform.rotate(
              angle: rotationAngle,
              alignment: Alignment.center,
              child: Center(
                child: AspectRatio(
                  aspectRatio: shouldRotate ? 3 / 4 : 4 / 3,
                  child: SizedBox.expand(
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width:
                            widget.controller.value.previewSize?.width ?? 1920,
                        height:
                            widget.controller.value.previewSize?.height ?? 1080,
                        child: CameraPreview(widget.controller),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Baut das animierte Fokusquadrat
  Widget _buildFocusPoint() {
    return Positioned(
      left: _focusPoint!.dx - 25, // Zentrieren des Quadrats um den Fokuspunkt
      top: _focusPoint!.dy - 25,
      child: AnimatedBuilder(
        animation: _focusAnimationController,
        builder: (context, child) {
          final double size = 50 - (_focusAnimationController.value * 10);
          return Opacity(
            opacity: 1.0 - _focusAnimationController.value * 0.5,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.white,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        },
      ),
    );
  }
}
