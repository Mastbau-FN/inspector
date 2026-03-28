import 'dart:io';
import 'dart:async';
import 'dart:math';

import 'package:MBG_Inspektionen/classes/data/checkpointdefect.dart';
import 'package:MBG_Inspektionen/fragments/loadingscreen/loadingView.dart';
import 'package:MBG_Inspektionen/pages/checkpointdefects.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';

import '../backend/api.dart';
import '../backend/categoryProgressState.dart';
import '../classes/data/checkpoint.dart';
import '../helpers/toast.dart';
import '../options.dart';
import 'camera/cameraModel.dart';
import 'camera/views/cameraMainPreview.dart';

/// Button zum Hinzufügen eines neuen Fotos mit Kamerasteuerung
class PrePhotoAdder extends StatelessWidget {
  final CheckPoint parent;
  final Future<Null> Function() onDone;
  final CheckPointDefectsModel model;

  PrePhotoAdder({
    required this.parent,
    required this.onDone,
    required this.model,
  });

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () {
          showDialog(
              barrierDismissible: false,
              context: context,
              builder: (context) => ChangeNotifierProvider(
                  create: (context) => CameraModel(),
                  child: Builder(builder: (context) {
                    return CameraForAdder(
                        parent: parent, onDone: onDone, model: model);
                  })));
        });
  }
}

/// Dialog mit Kamera zur Aufnahme von Bildern für neue Defekte
class CameraForAdder extends StatefulWidget {
  final parent;
  final Future<Null> Function() onDone;
  final CheckPointDefectsModel model;

  const CameraForAdder({
    Key? key,
    this.parent,
    required this.onDone,
    required this.model,
  }) : super(key: key);

  @override
  State<CameraForAdder> createState() => _CameraForAdderState();
}

class _CameraForAdderState extends State<CameraForAdder>
    with SingleTickerProviderStateMixin {
  // Animation-Controller
  static const animationDuration = Duration(milliseconds: 200);
  late Animation<double> animation;
  late AnimationController controller;

  // Status-Variablen
  bool firstOpen = true;
  bool withCamera = false;
  bool uploadingImage = false;
  List<XFile> queue = [];

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    openCam();
    controller = AnimationController(duration: animationDuration, vsync: this);
    animation = Tween<double>(begin: 0, end: 1).animate(controller)
      ..addListener(() {
        setState(() {
          // Animation-Aktualisierung
        });
      });
  }

  @override
  void dispose() {
    controller.dispose();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Stack(
      children: [
        Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(18.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (withCamera)
                    Expanded(
                      child: Padding(
                        padding: isLandscape
                            ? const EdgeInsets.fromLTRB(
                                25, 0, 32, 0) // Mehr Abstand im Querformat
                            : const EdgeInsets.fromLTRB(25, 0, 8, 0),
                        child: Consumer<CameraModel>(
                          builder: (context, model, child) =>
                              model.latestPic == null
                                  ? ChangeNotifierProvider.value(
                                      value: model.zoomM,
                                      child: Builder(builder: (context) {
                                        return _buildCameraWithControls(model);
                                      }),
                                    )
                                  : _buildCapturedImagePreview(model),
                        ),
                      ),
                    ),
                  Container(
                    margin: isLandscape
                        ? EdgeInsets.only(
                            left: 32) // Mehr Abstand im Querformat
                        : EdgeInsets.only(
                            top:
                                132), // Deutlich mehr vertikaler Abstand im Hochformat
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.bottomCenter,
                      children: [
                        // Bilderwarteschlange (nur anzeigen, wenn es Bilder in der Queue gibt)
                        if (queue.isNotEmpty && withCamera)
                          Positioned(
                            right: isLandscape
                                ? 70
                                : 0, // Im Querformat: zwischen Buttons und Bild, im Hochformat: über Buttons
                            bottom: isLandscape
                                ? 0
                                : 250, // Im Querformat: unten ausgerichtet, im Hochformat: mit deutlich mehr Abstand für Buttons
                            child: Container(
                              margin: EdgeInsets.only(bottom: 8),
                              child: _buildImageQueueWidget(),
                            ),
                          ),

                        Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Transform.translate(
                              offset: Offset(0, animation.value * -70),
                              child: Padding(
                                padding: const EdgeInsets.only(top: 100),
                                child: Consumer<CameraModel>(
                                  builder: (context, model, child) =>
                                      _buildCameraControls(context, model),
                                ),
                              ),
                            ),
                            const SizedBox(height: 5),
                            _buildCancelButton(context),
                          ],
                        ),
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

  // Kamerasteuerung mit Blitz- und Zoomkontrolle
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
          child: IconButton(
            icon: Icon(
              model.flashMode.icon,
              color: Colors.white,
            ),
            onPressed: model.toggleFlash,
            tooltip: 'Blitzmodus: ${model.flashMode.label}',
          ),
        ),

        // Zoomregler
        _buildZoomSlider(model),
      ],
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
              child: Consumer<ZoomModel>(
                builder: (context, zoomModel, _) {
                  return Slider(
                    value: zoomModel.zoom,
                    min: snapshot.data!.$1,
                    max: snapshot.data!.$2,
                    onChanged: (newZoom) => model.setZoom(newZoom),
                    activeColor: Colors.white,
                    inactiveColor: Colors.white.withValues(alpha: 0.5),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  // Abbrechen-Button
  Widget _buildCancelButton(BuildContext context) {
    return FloatingActionButton(
        backgroundColor: Colors.red,
        child: const Icon(Icons.cancel),
        onPressed: () {
          if (queue.isEmpty) {
            Provider.of<CameraModel>(context, listen: false).discardPic();
            closeCam();
            Navigator.of(context).pop();
            return;
          }

          // Letztes Bild aus der Warteschlange anzeigen
          final model = Provider.of<CameraModel>(context, listen: false);
          model.latestPic = queue.last;
          setState(() {
            queue.removeLast();
          });
        });
  }

  // Bild-Steuerungselemente
  Widget _buildCameraControls(BuildContext context, CameraModel model) {
    if (model.latestPic == null) {
      return FloatingActionButton(
        heroTag: 'takePhoto',
        backgroundColor: Colors.amber,
        child: Icon(withCamera ? Icons.camera : Icons.camera_alt),
        onPressed: withCamera ? () => _shoot(context) : openCam,
        tooltip: withCamera ? 'Foto aufnehmen' : 'Kamera öffnen',
      );
    } else {
      return Column(
        verticalDirection: VerticalDirection.up,
        children: [
          _buildConfirmButton(),
          const SizedBox(height: 10), // Reduzierter Abstand
          _buildDiscardButton(),
          const SizedBox(height: 10), // Reduzierter Abstand
          _buildAddToQueueButton(),
        ],
      );
    }
  }

  // Foto aufnehmen
  void _shoot(BuildContext context) async {
    try {
      final model = Provider.of<CameraModel>(context, listen: false);
      await model.shoot();
    } catch (e) {
      showToast("Fehler bei der Aufnahme: $e");
    }
  }

  // Bild verwerfen
  void _discardShot(BuildContext context) {
    Provider.of<CameraModel>(context, listen: false).discardPic();
  }

  // Bild zur Warteschlange hinzufügen
  Future<void> _addLatestToQueue(BuildContext context) async {
    final model = Provider.of<CameraModel>(context, listen: false);
    final pic = model.latestPic;

    if (pic != null) {
      setState(() {
        queue.add(pic);
      });
      model.discardPic();
    }
  }

  // Bilder hochladen
  Future<void> _onNewImages(List<XFile> queue, CheckPointDefect cp) async {
    final caller = widget.model.currentData;
    final isOffline = Options().forceOffline ||
        caller.forceOffline ||
        cp.forceOffline ||
        widget.parent.forceOffline;

    if (isOffline) {
      // markiere Datensätze explizit als offline, damit API nicht direkt sendet
      cp.forceOffline = true;
      caller.forceOffline = true;
    }

    await API()
        .uploadNewImagesOrFiles(cp, queue, caller: caller, forceUpdate: true);
  }

  // Bilder hochladen und neuen Defekt erstellen
  void _uploadShots(BuildContext context) async {
    setState(() {
      uploadingImage = true;
    });

    final caller = widget.model.currentData;
    final offlineMode = Options().forceOffline ||
        caller.forceOffline ||
        widget.parent.forceOffline;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (ncontext) => Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: CheckPointDefectsModel.adder(
              parent: widget.parent,
              onDone: (defect) async {
                if (offlineMode) {
                  defect.forceOffline = true;
                  try {
                    widget.parent.forceOffline = true;
                  } catch (_) {}
                }
                CheckPointDefect? newDefect =
                    await API().setNew(defect, caller: widget.parent);
                if (newDefect != null &&
                    newDefect.ereArt != OufnessChooser.none) {
                  CategoryProgressState.instance
                      .markCheckpointEditedByCoordinates(
                    pjNr: widget.parent.pjNr,
                    categoryIndex: widget.parent.category_index,
                    checkpointIndex: widget.parent.index,
                  );
                }
                await API().update(newDefect!, caller: widget.parent);
                await widget.onDone();
                await _onNewImages(queue, newDefect);
                await widget.onDone();
                queue = [];
              },
              onCancel: () {
                Navigator.of(ncontext).pop();
              },
            ),
          ),
        ),
      ),
    );
    closeCam();
  }

  // Neue Widget-Version der Bilderwarteschlange für bessere Positionierung
  Widget _buildImageQueueWidget() {
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
                  color: Colors.black.withValues(alpha: 0.7),
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
                      color: Colors.black.withValues(alpha: 0.3),
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

  // Button zum Verwerfen des aktuellen Bildes
  Widget _buildDiscardButton() {
    return SizedBox(
      width: 48, // Kleinere Größe
      height: 48, // Kleinere Größe
      child: FloatingActionButton(
        heroTag: 'discardPhoto',
        backgroundColor: Colors.red,
        child: const Icon(Icons.replay, size: 20), // Kleineres Icon
        onPressed: () => _discardShot(context),
        tooltip: 'Verwerfen und neu aufnehmen',
      ),
    );
  }

  // Button zum Bestätigen und Hochladen
  Widget _buildConfirmButton() {
    return SizedBox(
      width: 48, // Kleinere Größe
      height: 48, // Kleinere Größe
      child: FloatingActionButton(
        heroTag: 'confirmPhoto',
        backgroundColor: Colors.green,
        child: uploadingImage
            ? const LoadingView()
            : const Icon(Icons.check, size: 20), // Kleineres Icon
        onPressed: () =>
            _addLatestToQueue(context).then((_) => _uploadShots(context)),
        tooltip: 'Bestätigen und hochladen',
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
              onPressed: () => _addLatestToQueue(context),
              tooltip: 'Zur Warteschlange hinzufügen',
            ),
          );
  }

  // Kamera öffnen
  void openCam() {
    setState(() {
      withCamera = true;
    });
  }

  // Kamera schließen
  void closeCam() {
    setState(() {
      withCamera = false;
    });
  }

  // Zweites Öffnen markieren
  void secondOpen() {
    setState(() {
      firstOpen = false;
    });
  }

  // Zeigt das aufgenommene Bild mit korrekter Ausrichtung an
  Widget _buildCapturedImagePreview(CameraModel model) {
    final file = File(model.latestPic!.path);
    return FutureBuilder<Size>(
      future: _getImageDimensions(file),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
              child: CircularProgressIndicator(color: Colors.white));
        }

        final isLandscape =
            MediaQuery.of(context).orientation == Orientation.landscape;
        final imageWidth = snapshot.data!.width;
        final imageHeight = snapshot.data!.height;
        final imageRatio = imageWidth / imageHeight;

        // Bildschirmmaße abrufen
        final screenSize = MediaQuery.of(context).size;

        // Größe des Vorschaufensters basierend auf Bildverhältnis berechnen
        double displayWidth, displayHeight;

        if (isLandscape) {
          // Im Querformat - Höhe begrenzen
          displayHeight = screenSize.height * 0.7;
          displayWidth = displayHeight * imageRatio;
          // Breite begrenzen, falls nötig
          if (displayWidth > screenSize.width * 0.8) {
            displayWidth = screenSize.width * 0.8;
            displayHeight = displayWidth / imageRatio;
          }
        } else {
          // Im Hochformat - Breite begrenzen
          displayWidth = screenSize.width * 0.8;
          displayHeight = displayWidth / imageRatio;
          // Höhe begrenzen, falls nötig
          if (displayHeight > screenSize.height * 0.7) {
            displayHeight = screenSize.height * 0.7;
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
                      color: Colors.black.withValues(alpha: 0.6),
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
}
