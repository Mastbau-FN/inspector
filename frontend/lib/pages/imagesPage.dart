import 'dart:io';
import 'dart:ui';
import 'dart:math';
import 'dart:async';

import 'package:MBG_Inspektionen/classes/imageData.dart';
import 'package:MBG_Inspektionen/fragments/MainDrawer.dart';
import 'package:MBG_Inspektionen/fragments/camera/cameraModel.dart';
import 'package:MBG_Inspektionen/fragments/camera/views/cameraMainPreview.dart';
import 'package:MBG_Inspektionen/fragments/loadingscreen/loadingView.dart';
import 'package:MBG_Inspektionen/l10n/locales.dart';
import 'package:MBG_Inspektionen/helpers/toast.dart';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:collection/collection.dart';

import 'package:MBG_Inspektionen/fragments/imageWrap.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

/// Hauptseite für die Bilderverwaltung
class ImagesPage<T extends Object> extends StatelessWidget {
  // Streams für die Bilddaten
  late final List<Stream<ImageData<T>?>> _images;

  // Callback-Funktionen
  final Future<String?> Function(List<XFile>) onNewImages;
  final Function(T) onDelete;
  final Function(T) onStar;
  final Function(T) onShare;

  // Konfigurationsoptionen
  final int columnCount;
  final bool hasMainImage;
  final bool intendsToAddPicture;

  // Standard-Callback-Funktionen
  static Future<String?> _defaultAdd(List<XFile> list) async {
    showToast(S.current!.notAvailable);
    return "";
  }

  static _default(Object _) => showToast(S.current!.notAvailable);

  /// Konstruktor für direkte Bildlisten
  ImagesPage.constant({
    List<ImageData<T>?>? images = const [],
    this.columnCount = 4,
    Key? key,
    this.onNewImages = _defaultAdd,
    this.onDelete = _default,
    this.onStar = _default,
    this.onShare = _default,
    this.hasMainImage = false,
    this.intendsToAddPicture = false,
  }) : super(key: key) {
    this._images =
        images?.whereNotNull().map((e) => Stream.value(e)).toList() ?? [];
  }

  /// Konstruktor für Future-basierte Bildlisten
  ImagesPage.futured({
    List<Future<ImageData<T>?>>? futureImages = const [],
    this.columnCount = 4,
    Key? key,
    this.onNewImages = _defaultAdd,
    this.onDelete = _default,
    this.onStar = _default,
    this.onShare = _default,
    this.hasMainImage = false,
    this.intendsToAddPicture = false,
  }) : super(key: key) {
    this._images =
        futureImages?.map((e) => Stream.fromFuture(e)).toList() ?? [];
  }

  /// Konstruktor für Stream-basierte Bildlisten
  ImagesPage.streamed({
    List<Stream<ImageData<T>?>>? imageStreams = const [],
    this.columnCount = 4,
    Key? key,
    this.onNewImages = _defaultAdd,
    this.onDelete = _default,
    this.onStar = _default,
    this.onShare = _default,
    this.hasMainImage = false,
    this.intendsToAddPicture = false,
  }) : super(key: key) {
    this._images = imageStreams ?? [];
  }

  final ImagePicker _picker = ImagePicker();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Hauptscaffold mit Bildergalerie
        Scaffold(
          endDrawer: MainDrawer(),
          appBar: AppBar(
            title: Text('Bilder'),
            elevation: 0,
            actions: [
              Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.more_vert),
                  onPressed: () => Scaffold.of(context).openEndDrawer(),
                  tooltip: 'Menü öffnen',
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              // Hinweis zur Bilderverwaltung
              if (_images.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.photo_library_outlined,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Keine Bilder vorhanden',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Fotos aufnehmen oder aus der Galerie hinzufügen',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              else
                // Bildergalerie
                Expanded(
                  child: ImageWrap<T>.streamed(
                    images: _images,
                    onDelete: onDelete,
                    onShare: onShare,
                    onStar: onStar,
                    hasFav: hasMainImage,
                  ),
                ),
            ],
          ),
        ),

        // Kamera-Provider und Bildaufnahme-Button
        ChangeNotifierProvider(
          create: (context) => CameraModel(),
          child: Builder(builder: (context) {
            return ImageCapturePanel(
              picker: _picker,
              onNewImages: onNewImages,
              autoExpand: intendsToAddPicture,
            );
          }),
        ),
      ],
    );
  }
}

/// Panel für die Bildaufnahme und -verwaltung
class ImageCapturePanel extends StatefulWidget {
  final bool autoExpand;
  final ImagePicker _picker;
  final Future<String?> Function(List<XFile>) onNewImages;

  const ImageCapturePanel({
    Key? key,
    required ImagePicker picker,
    required this.onNewImages,
    this.autoExpand = false,
  })  : _picker = picker,
        super(key: key);

  @override
  State<ImageCapturePanel> createState() => _ImageCapturePanelState();
}

class _ImageCapturePanelState extends State<ImageCapturePanel>
    with SingleTickerProviderStateMixin {
  // Animation-Controller
  static const animationDuration = Duration(milliseconds: 250);
  late Animation<double> animation;
  late AnimationController controller;

  // Panel-Zustand
  bool expanded = false;
  bool withCamera = false;
  bool uploadingImage = false;
  List<XFile> queue = [];

  @override
  void initState() {
    super.initState();
    controller = AnimationController(duration: animationDuration, vsync: this);
    animation = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
      parent: controller,
      curve: Curves.easeInOut,
    ))
      ..addListener(() {
        setState(() {
          // Animation-Aktualisierung
        });
      });

    if (widget.autoExpand) {
      // Automatisch öffnen, wenn intendsToAddPicture true ist
      Future.microtask(() => expand());
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  // Panel-Steuerungsfunktionen
  void expand() {
    controller.forward();
    setState(() {
      expanded = true;
    });
  }

  void collapse() {
    controller.reverse();
    closeCam();

    Future.delayed(animationDuration, () {
      setState(() {
        expanded = false;
        uploadingImage = false;
      });
    });
  }

  void openCam() {
    setState(() {
      withCamera = true;
    });
  }

  void closeCam() {
    setState(() {
      withCamera = false;
    });
  }

  // Kamera-Funktionen
  void shoot(BuildContext context) async {
    try {
      final model = Provider.of<CameraModel>(context, listen: false);
      await model.shoot();
    } catch (e) {
      showToast("Fehler bei der Aufnahme: $e");
    }
  }

  void discardShot(BuildContext context) {
    Provider.of<CameraModel>(context, listen: false).discardPic();
  }

  Future<void> addLatestToQueue(BuildContext context) async {
    final model = Provider.of<CameraModel>(context, listen: false);
    final pic = model.latestPic;

    if (pic != null) {
      setState(() {
        queue.add(pic);
      });
      model.discardPic();
    }
  }

  void uploadShots(BuildContext context) async {
    if (queue.isEmpty) return;

    setState(() {
      uploadingImage = true;
    });

    try {
      final result = await widget.onNewImages(queue);
      if (kDebugMode) {
        showToast(result ??
            S.of(context).uploadFinishedNoIdeaWhetherSuccessedOrFailedTho);
      }
      setState(() {
        queue = [];
      });
    } catch (e) {
      showToast("Fehler beim Hochladen: $e");
    } finally {
      collapse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(
        sigmaX: 5.0 * animation.value,
        sigmaY: 5.0 * animation.value,
        tileMode: TileMode.mirror,
      ),
      child: _buildCapturePanel(),
    );
  }

  Widget _buildCapturePanel() {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Stack(
      children: [
        // Hintergrund für erweiterten Zustand
        if (expanded)
          GestureDetector(
            onTap: () {
              // Nur schließen, wenn nicht aktiv mit der Kamera arbeitet
              if (!withCamera) {
                collapse();
              }
            },
            child: Container(
              color: Colors.black.withOpacity(0.3 * animation.value),
              width: double.infinity,
              height: double.infinity,
            ),
          ),

        // Hauptpanel
        Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Kamera-Vorschau
                  if (withCamera)
                    Expanded(
                      child: Padding(
                        padding: isLandscape
                            ? const EdgeInsets.fromLTRB(20, 0, 32, 0)
                            : const EdgeInsets.fromLTRB(20, 0, 8, 0),
                        child: Consumer<CameraModel>(
                          builder: (context, model, child) => model.latestPic ==
                                  null
                              ? ChangeNotifierProvider.value(
                                  value: model.zoomM,
                                  child: _buildCameraWithControls(model),
                                )
                              : _buildCapturedImagePreview(model, isLandscape),
                        ),
                      ),
                    ),

                  // Steuerungs-Buttons mit zusätzlichem Container für mehr Abstand
                  Container(
                    margin: isLandscape
                        ? EdgeInsets.only(
                            left: 32) // Mehr Abstand im Querformat
                        : EdgeInsets.only(
                            top:
                                132), // Deutlich mehr vertikaler Abstand im Hochformat
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        // Bilderwarteschlange (nur anzeigen, wenn es Bilder in der Queue gibt)
                        if (queue.isNotEmpty && withCamera)
                          Transform.translate(
                            offset: isLandscape
                                ? Offset(-60,
                                    0) // Im Querformat: links neben den Buttons
                                : Offset(0,
                                    -300), // Im Hochformat: deutlich weiter über den Buttons
                            child: Container(
                              margin: isLandscape
                                  ? EdgeInsets.only(bottom: 8)
                                  : EdgeInsets.only(right: 8),
                              child: _buildImageQueue(),
                            ),
                          ),

                        // Systembilder-Button
                        if (expanded && !withCamera)
                          Transform.translate(
                            offset: Offset(0, animation.value * -130),
                            child: Padding(
                              padding: const EdgeInsets.only(top: 160),
                              child: _buildSystemImagesButton(),
                            ),
                          ),

                        // Kamerasteuerung
                        if (expanded)
                          Transform.translate(
                            offset: Offset(0, animation.value * -70),
                            child: Padding(
                              padding: const EdgeInsets.only(top: 100),
                              child: Consumer<CameraModel>(
                                builder: (context, model, child) =>
                                    _buildImageCaptureControls(model),
                              ),
                            ),
                          ),

                        // Hauptaktionsbutton
                        _buildMainActionButton(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Kamerasteuerung mit UI-Elementen
  Widget _buildCameraWithControls(CameraModel model) {
    return CameraPreviewOnly(
      children: [
        // Kamera wechseln
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(25),
          ),
          child: IconButton(
            icon: const Icon(Icons.switch_camera, color: Colors.white),
            onPressed: model.nextCamera,
            tooltip: 'Kamera wechseln',
          ),
        ),

        // Blitzsteuerung
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(25),
          ),
          child: _buildFlashButton(model),
        ),

        // Zoomregler
        _buildZoomSlider(model),
      ],
    );
  }

  // Blitzsteuerung
  Widget _buildFlashButton(CameraModel model) {
    return IconButton(
      icon: Icon(
        model.flashMode.icon,
        color: Colors.white,
      ),
      onPressed: model.toggleFlash,
      tooltip: 'Blitzmodus: ${model.flashMode.label}',
    );
  }

  // Zoomregler
  Widget _buildZoomSlider(CameraModel model) {
    return FutureBuilder<(double, double)>(
        future: model.zoomRange,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return Container();

          return Container(
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.symmetric(vertical: 4),
            margin: const EdgeInsets.only(top: 8),
            child: SizedBox(
              height: 200,
              width: 50,
              child: RotatedBox(
                quarterTurns: 1,
                child: Consumer<ZoomModel>(builder: (context, zoomModel, _) {
                  return Slider(
                    value: zoomModel.zoom,
                    min: snapshot.data!.$1,
                    max: snapshot.data!.$2,
                    onChanged: (newZoom) => model.setZoom(newZoom),
                    activeColor: Colors.white,
                    inactiveColor: Colors.white.withOpacity(0.5),
                  );
                }),
              ),
            ),
          );
        });
  }

  // Button zum Auswählen von Bildern aus dem System
  Widget _buildSystemImagesButton() {
    return FloatingActionButton(
      heroTag: 'systemImages',
      backgroundColor: Colors.deepPurple,
      child: const Icon(Icons.photo_library),
      onPressed: () async {
        try {
          final newImages = await widget._picker.pickMultiImage();
          if (newImages != null && newImages.isNotEmpty) {
            final result = await widget.onNewImages(newImages);
            if (kDebugMode) {
              showToast(result ??
                  S
                      .of(context)
                      .uploadFinishedNoIdeaWhetherSuccessedOrFailedTho);
            }
          }
          collapse();
        } catch (e) {
          showToast("Fehler beim Laden der Bilder: $e");
        }
      },
      tooltip: 'Bilder aus Galerie hinzufügen',
    );
  }

  // Hauptaktionsbutton (Öffnen/Schließen des Panels)
  Widget _buildMainActionButton() {
    return FloatingActionButton(
      heroTag: 'mainAction',
      backgroundColor: expanded ? Colors.red : Colors.blue,
      child: Icon(expanded ? Icons.close : Icons.add_a_photo),
      onPressed: expanded
          ? () {
              if (queue.isEmpty) {
                Provider.of<CameraModel>(context, listen: false).discardPic();
                collapse();
                return;
              }

              // Letztes Bild aus der Warteschlange anzeigen
              final model = Provider.of<CameraModel>(context, listen: false);
              model.latestPic = queue.last;
              setState(() {
                queue.removeLast();
              });
            }
          : expand,
      tooltip: expanded ? 'Abbrechen' : 'Bilder hinzufügen',
    );
  }

  // Bildaufnahmesteuerung
  Widget _buildImageCaptureControls(CameraModel model) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    // Wenn keine Kamera geöffnet oder kein Bild aufgenommen
    if (!withCamera || model.latestPic == null) {
      return FloatingActionButton(
        heroTag: 'cameraControl',
        backgroundColor: Colors.amber,
        child: Icon(withCamera ? Icons.camera : Icons.camera_alt),
        onPressed: withCamera ? () => shoot(context) : openCam,
        tooltip: withCamera ? 'Foto aufnehmen' : 'Kamera öffnen',
      );
    }

    // Layout für die Bildvorschau und Steuerelemente
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Buttons immer vertikal anordnen
        _buildAcceptButton(),
        const SizedBox(height: 10), // Reduzierter Abstand zwischen Buttons
        _buildDiscardButton(),
        const SizedBox(height: 10), // Reduzierter Abstand zwischen Buttons
        _buildAddToQueueButton(),
      ],
    );
  }

  // Button zum Akzeptieren und Hochladen
  Widget _buildAcceptButton() {
    return SizedBox(
      width: 48, // Kleinere Größe
      height: 48, // Kleinere Größe
      child: FloatingActionButton(
        heroTag: 'accept',
        backgroundColor: Colors.green,
        child: uploadingImage
            ? const CircularProgressIndicator(
                color: Colors.white, strokeWidth: 3)
            : const Icon(Icons.check, size: 20), // Kleineres Icon
        onPressed: () {
          addLatestToQueue(context).then((_) {
            Provider.of<CameraModel>(context, listen: false).disposeCamera();
            uploadShots(context);
          });
        },
        tooltip: 'Bestätigen und hochladen',
      ),
    );
  }

  // Button zum Verwerfen des aktuellen Bildes
  Widget _buildDiscardButton() {
    return SizedBox(
      width: 48, // Kleinere Größe
      height: 48, // Kleinere Größe
      child: FloatingActionButton(
        heroTag: 'discard',
        backgroundColor: Colors.red,
        child: const Icon(Icons.refresh, size: 20), // Kleineres Icon
        onPressed: () => discardShot(context),
        tooltip: 'Verwerfen und neu aufnehmen',
      ),
    );
  }

  // Button zum Hinzufügen zur Warteschlange
  Widget _buildAddToQueueButton() {
    return uploadingImage
        ? Container()
        : SizedBox(
            width: 48, // Kleinere Größe
            height: 48, // Kleinere Größe
            child: FloatingActionButton(
              heroTag: 'addToQueue',
              backgroundColor: Colors.blue,
              child: const Icon(Icons.add_photo_alternate,
                  size: 20), // Kleineres Icon
              onPressed: () => addLatestToQueue(context),
              tooltip: 'Zur Warteschlange hinzufügen',
            ),
          );
  }

  // Zeigt das aufgenommene Bild mit korrekter Ausrichtung an
  Widget _buildCapturedImagePreview(CameraModel model, bool isLandscape) {
    final file = File(model.latestPic!.path);
    return FutureBuilder<Size>(
      future: _getImageDimensions(file),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
              child: CircularProgressIndicator(color: Colors.white));
        }

        final imageWidth = snapshot.data!.width;
        final imageHeight = snapshot.data!.height;
        final imageRatio = imageWidth / imageHeight;

        // Bildschirmmaße abrufen
        final screenSize = MediaQuery.of(context).size;

        // Größe des Vorschaufensters basierend auf Bildverhältnis berechnen
        double displayWidth, displayHeight;

        if (isLandscape) {
          // Im Querformat - Höhe begrenzen
          displayHeight = screenSize.height * 0.8;
          displayWidth = displayHeight * imageRatio;
          // Breite begrenzen, falls nötig
          if (displayWidth > screenSize.width * 0.6) {
            displayWidth = screenSize.width * 0.6;
            displayHeight = displayWidth / imageRatio;
          }
        } else {
          // Im Hochformat - Breite begrenzen
          displayWidth = screenSize.width * 0.9;
          displayHeight = displayWidth / imageRatio;
          // Höhe begrenzen, falls nötig
          if (displayHeight > screenSize.height * 0.6) {
            displayHeight = screenSize.height * 0.6;
            displayWidth = displayHeight * imageRatio;
          }
        }

        // Überprüfen, ob das Bild falsch ausgerichtet ist
        final shouldRotate =
            (isLandscape && imageRatio < 1) || (!isLandscape && imageRatio > 1);

        // Berechnen des korrekten Rotationswinkels basierend auf der Ausrichtung
        double rotationAngle;
        if (isLandscape) {
          // Im Querformat-Modus
          rotationAngle = shouldRotate ? pi / 2 : 0;
        } else {
          // Im Hochformat-Modus
          rotationAngle = shouldRotate ? pi / 2 : 0;
        }

        return Container(
          width: displayWidth,
          height: displayHeight,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(15),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Bildanzeige mit Drehung bei Bedarf
                Center(
                  child: Transform.rotate(
                    angle: rotationAngle,
                    child: AspectRatio(
                      aspectRatio: shouldRotate ? 1 / imageRatio : imageRatio,
                      child: Image.file(
                        file,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),

                // Kleine Infoanzeige
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Vorschau',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Hilfsfunktion zum Abrufen der Bildabmessungen
  Future<Size> _getImageDimensions(File imageFile) async {
    final Completer<Size> completer = Completer();
    final Image image = Image.file(imageFile);
    image.image
        .resolve(const ImageConfiguration())
        .addListener(ImageStreamListener((ImageInfo info, bool _) {
      completer.complete(Size(
        info.image.width.toDouble(),
        info.image.height.toDouble(),
      ));
    }));
    return completer.future;
  }

  // Anzeige der Bild-Warteschlange
  Widget _buildImageQueue() {
    int totalImages = queue.length;
    if (totalImages == 0) return Container();

    int imagesToShow = totalImages.clamp(0, 5);
    List<XFile> visibleImages = queue.skip(totalImages - imagesToShow).toList();
    int remainingImages = totalImages - imagesToShow;

    return Container(
      width: 50,
      height: imagesToShow * 30 + 50,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Indikator für weitere Bilder
          if (remainingImages > 0)
            Positioned(
              top: 0,
              child: Container(
                height: 50,
                width: 50,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Text(
                  "+$remainingImages",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

          // Bilder in der Warteschlange
          ...visibleImages.asMap().entries.map((entry) {
            int idx = entry.key;
            XFile file = entry.value;

            return Positioned(
              top: (idx + (remainingImages > 0 ? 1 : 0)) * 30.0,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 5,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    height: 50,
                    width: 50,
                    child: Image.file(
                      File(file.path),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
