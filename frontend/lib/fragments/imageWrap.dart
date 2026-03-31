import 'package:MBG_Inspektionen/classes/imageData.dart';
import 'package:MBG_Inspektionen/fragments/loadingscreen/loadingView.dart';
import 'package:MBG_Inspektionen/helpers/toast.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'package:provider/provider.dart';

import 'package:MBG_Inspektionen/l10n/locales.dart';
import 'galleryWrapper.dart';

class ImageWrap<T extends Object> extends StatefulWidget {
  static FutureOr<void> _default(Object _) {
    showToast(S.current!.notAvailable);
  }

  static FutureOr<void> _defaultRotate(Object _, int __) {
    showToast(S.current!.notAvailable);
  }

  final FutureOr<void> Function(T) onDelete;
  final FutureOr<void> Function(T) onStar;
  final FutureOr<void> Function(T) onShare;
  final FutureOr<void> Function(T, int deltaQuarterTurns) onRotate;
  final bool selectionMode;
  final Set<T> selectedIds;
  final ValueChanged<T>? onToggleSelection;
  final void Function(T id, bool selected)? onSetSelection;
  final ValueChanged<Set<T>>? onVisibleIdsChanged;

  final bool? hasFav;
  final List<Stream<ImageData<T>?>> images;
  final int columnCount;
  ImageWrap.constant({
    List<ImageData<T>> images = const [],
    this.columnCount = 4,
    Key? key,
    this.hasFav,
    this.onDelete = _default,
    this.onStar = _default,
    this.onShare = _default,
    this.onRotate = _defaultRotate,
    this.selectionMode = false,
    Set<T>? selectedIds,
    this.onToggleSelection,
    this.onSetSelection,
    this.onVisibleIdsChanged,
  })  : this.images = images.map((e) => Stream.value(e)).toList(),
        this.selectedIds = selectedIds ?? <T>{},
        super(key: key);

  ImageWrap.futured({
    required List<Future<ImageData<T>?>> images,
    this.columnCount = 4,
    Key? key,
    this.hasFav,
    this.onDelete = _default,
    this.onStar = _default,
    this.onShare = _default,
    this.onRotate = _defaultRotate,
    this.selectionMode = false,
    Set<T>? selectedIds,
    this.onToggleSelection,
    this.onSetSelection,
    this.onVisibleIdsChanged,
  })  : this.images = images.map((e) => Stream.fromFuture(e)).toList(),
        this.selectedIds = selectedIds ?? <T>{},
        super(key: key);

  ImageWrap.streamed({
    required this.images,
    this.columnCount = 4,
    Key? key,
    this.hasFav,
    this.onDelete = _default,
    this.onStar = _default,
    this.onShare = _default,
    this.onRotate = _defaultRotate,
    this.selectionMode = false,
    Set<T>? selectedIds,
    this.onToggleSelection,
    this.onSetSelection,
    this.onVisibleIdsChanged,
  })  : this.selectedIds = selectedIds ?? <T>{},
        super(key: key);

  @override
  State<ImageWrap<T>> createState() => _ImageWrapState<T>();
}

class _ImageWrapState<T extends Object> extends State<ImageWrap<T>> {
  late List<ImageItem<T>> _allImages;
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _gridKey = GlobalKey();
  List<ImageItem<T>> _currentVisibleImages = const [];
  bool _dragSelecting = false;
  bool _dragSelectValue = true;
  final Set<int> _dragTouchedIndices = <int>{};
  int? _lastDragIndex;

  @override
  void initState() {
    super.initState();
    _allImages = _createItemsFromStreams(widget.images);
  }

  @override
  void didUpdateWidget(covariant ImageWrap<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.images, widget.images)) {
      _disposeItems(_allImages);
      _allImages = _createItemsFromStreams(widget.images);
    }
  }

  @override
  void dispose() {
    _disposeItems(_allImages);
    _scrollController.dispose();
    super.dispose();
  }

  List<ImageItem<T>> _createItemsFromStreams(
      List<Stream<ImageData<T>?>> streams) {
    return streams.map((e) => ImageItem.fromImageDataStream(e)).toList();
  }

  void _disposeItems(List<ImageItem<T>> items) {
    for (final item in items) {
      item.dispose();
    }
  }

  void _startDragSelection(Offset globalPosition) {
    if (!widget.selectionMode) return;
    final index = _indexFromGlobalPosition(globalPosition);
    if (index == null) return;
    if (index < 0 || index >= _currentVisibleImages.length) return;

    final id = _currentVisibleImages[index].image?.id;
    if (id == null || id is! T) return;

    _dragSelecting = true;
    _dragTouchedIndices
      ..clear()
      ..add(index);
    _lastDragIndex = index;
    _dragSelectValue = !widget.selectedIds.contains(id);
    widget.onSetSelection?.call(id, _dragSelectValue);
  }

  void _updateDragSelection(Offset globalPosition) {
    if (!_dragSelecting) return;
    final index = _indexFromGlobalPosition(globalPosition);
    if (index == null) return;
    if (index == _lastDragIndex) return;
    if (index < 0 || index >= _currentVisibleImages.length) return;
    _lastDragIndex = index;
    if (!_dragTouchedIndices.add(index)) return;

    final id = _currentVisibleImages[index].image?.id;
    if (id == null || id is! T) return;
    widget.onSetSelection?.call(id, _dragSelectValue);
  }

  void _endDragSelection() {
    _dragSelecting = false;
    _dragTouchedIndices.clear();
    _lastDragIndex = null;
  }

  int? _indexFromGlobalPosition(Offset globalPosition) {
    final context = _gridKey.currentContext;
    if (context == null) return null;
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox) return null;

    final local = renderObject.globalToLocal(globalPosition);
    final width = renderObject.size.width;
    final height = renderObject.size.height;
    if (local.dx < 0 || local.dy < 0 || local.dx > width || local.dy > height) {
      return null;
    }

    const padding = 2.0;
    final usableWidth = (width - (padding * 2)).clamp(1.0, double.infinity);
    final tileExtent = usableWidth / widget.columnCount;
    final x = local.dx - padding;
    final y = local.dy + _scrollController.offset - padding;
    if (x < 0 || y < 0) return null;

    final col = (x / tileExtent).floor();
    final row = (y / tileExtent).floor();
    if (col < 0 || col >= widget.columnCount || row < 0) return null;

    final index = row * widget.columnCount + col;
    if (index < 0 || index >= _currentVisibleImages.length) return null;
    return index;
  }

  @override
  Widget build(BuildContext context) => Builder(
        builder: (context) {
          return AnimatedBuilder(
            animation: Listenable.merge(_allImages),
            builder: (context, _) {
              final visibleImages = _allImages.where((e) => !e.hidden).toList();
              _currentVisibleImages = visibleImages;
              final visibleIds =
                  visibleImages.map((e) => e.image?.id).whereType<T>().toSet();
              WidgetsBinding.instance.addPostFrameCallback((_) {
                widget.onVisibleIdsChanged?.call(visibleIds);
              });
              final total = visibleImages.length;
              final loaded = visibleImages.where((e) => e.image != null).length;
              final fraction =
                  (total == 0) ? 0.0 : (loaded / total).clamp(0.0, 1.0);

              return Column(
                children: [
                  if (total > 0 && loaded < total)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                      child: Row(
                        children: [
                          Text('Bilder: $loaded/$total',
                              style: Theme.of(context).textTheme.bodySmall),
                          const SizedBox(width: 10),
                          Expanded(
                            child: LinearProgressIndicator(value: fraction),
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onPanStart: widget.selectionMode
                          ? (details) => _startDragSelection(
                                details.globalPosition,
                              )
                          : null,
                      onPanUpdate: widget.selectionMode
                          ? (details) => _updateDragSelection(
                                details.globalPosition,
                              )
                          : null,
                      onPanEnd: widget.selectionMode
                          ? (_) => _endDragSelection()
                          : null,
                      onPanCancel:
                          widget.selectionMode ? _endDragSelection : null,
                      child: GridView.builder(
                        key: _gridKey,
                        controller: _scrollController,
                        padding: const EdgeInsets.all(2.0),
                        itemCount: visibleImages.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: widget.columnCount,
                        ),
                        itemBuilder: (context, i) =>
                            OpenableImageView<T>.scrollable(
                          onDelete: widget.onDelete,
                          onShare: widget.onShare,
                          onStar: widget.onStar,
                          onRotate: widget.onRotate,
                          currentIndex: i,
                          chosenIndex: (widget.hasFav ?? true) &&
                                  visibleImages.isNotEmpty
                              ? 0
                              : -1, //// make this dynamic on callback or something for #20
                          // instead solve #36 and move chosen image to front
                          allImages: visibleImages,
                          selectionMode: widget.selectionMode,
                          selectedIds: widget.selectedIds,
                          onToggleSelection: widget.onToggleSelection,
                          approxWidth: MediaQuery.of(context).size.width /
                              widget.columnCount,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      );
}

class OpenableImageView<T extends Object> extends StatelessWidget {
  static FutureOr<void> _default(_) {
    showToast(S.current!.notAvailable);
  }

  static FutureOr<void> _defaultRotate(_, __) {
    showToast(S.current!.notAvailable);
  }

  final FutureOr<void> Function(T) onDelete;
  final FutureOr<void> Function(T) onStar;
  final FutureOr<void> Function(T) onShare;
  final FutureOr<void> Function(T, int deltaQuarterTurns) onRotate;

  ///expected width to determine resolution
  final num approxWidth;

  ///which index has the main image ; -1 means none is chosen
  final int chosenIndex;

  ///the index of the image that shall be opened
  final int currentIndex;

  ///an optional List of all images on which we can scroll to
  final List<ImageItem<T>> allImages;
  final bool selectionMode;
  final Set<T> selectedIds;
  final ValueChanged<T>? onToggleSelection;

  OpenableImageView.scrollable({
    //which item from this list shall be opened
    required this.currentIndex,
    required this.allImages,
    Key? key,
    this.chosenIndex = -1,
    this.onDelete = _default,
    this.onStar = _default,
    this.onShare = _default,
    this.onRotate = _defaultRotate,
    this.selectionMode = false,
    Set<T>? selectedIds,
    this.onToggleSelection,
    required this.approxWidth,
  })  : selectedIds = selectedIds ?? <T>{},
        assert(0 <= currentIndex && currentIndex < (allImages.length)),
        super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: allImages[currentIndex],
      child: Builder(builder: (context) {
        final currentId = allImages[currentIndex].image?.id;
        final isSelected = currentId != null &&
            currentId is T &&
            selectedIds.contains(currentId);
        return Container(
          child: Stack(
            children: [
              Consumer<ImageItem>(builder: (context, imgModel, _) {
                if (imgModel.hidden) return const SizedBox.shrink();
                return _heroImg(context, imgModel);
              }),
              if (chosenIndex == currentIndex)
                Positioned(
                  child: Icon(
                    //todo: maybe add shadow or border to better see it
                    Icons.star,
                    color: Colors.amber,
                  ),
                  left: 8,
                  top: 8,
                ),
              if (selectionMode && currentId != null && currentId is T)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isSelected
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color:
                          isSelected ? Colors.lightGreenAccent : Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }

  Widget _heroImg(context, ImageItem img) {
    Object tag = img.tag;
    return TextButton(
      style: TextButton.styleFrom(
        padding: EdgeInsets.zero,
      ),
      child: Hero(
        tag: tag,
        child: AspectRatio(
          aspectRatio: 1,
          child: FittedImageContainer(
            item: img,
            approxWidth: approxWidth,
          ),
        ),
      ),
      onLongPress: () => _onLongPress(context, tag),
      onPressed: () {
        final id = img.image?.id;
        if (selectionMode && id != null && id is T) {
          onToggleSelection?.call(id);
          return;
        }
        _onShortPress(context, img);
      },
    );
  }

  void _onShortPress(BuildContext context, ImageItem current) {
    if (current.hidden) return;
    final visible = allImages.where((e) => !e.hidden).toList();
    final visibleIndex = visible.indexWhere((e) => identical(e, current));
    if (visibleIndex < 0) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (c) => GalleryPhotoViewWrapper(
          galleryItems: visible,
          backgroundDecoration:
              BoxDecoration(color: Theme.of(context).canvasColor),
          initialIndex: visibleIndex,
          scrollDirection: Axis.horizontal,
          onRotate: (id, deltaQuarterTurns) async {
            if (id is T) {
              await Future.sync(() => onRotate(id, deltaQuarterTurns));
            }
          },
        ),
      ),
    );
  }

  Future<void> _onLongPress(context, tag) async {
    final id = allImages[currentIndex].image?.id;
    if (selectionMode && id != null && id is T) {
      onToggleSelection?.call(id);
      return;
    }

    switch (await showDialog<ImageOptions>(
        barrierColor: Colors.black54,
        context: context,
        builder: (BuildContext context) {
          return SimpleDialog(
            title: Text(S.of(context).optionsForThisImageHeadLine),
            children: <Widget>[
              _option(
                context: context,
                description: S.of(context).permanentlyRemoveImage,
                icon: Icon(
                  Icons.delete,
                  color: Colors.red,
                ),
                returnCase: ImageOptions.delete,
              ),
              _option(
                context: context,
                description: S.of(context).setAsMainImage,
                icon: Icon(
                  Icons.star,
                  color: Colors.amber[300],
                ),
                returnCase: ImageOptions.setMain,
              ),
              _option(
                context: context,
                description: S.of(context).shareImage,
                icon: Icon(
                  Icons.share,
                  color: Colors.blue,
                ),
                returnCase: ImageOptions.share,
              ),
            ],
          );
        })) {
      case ImageOptions.delete:
        debugPrint("image Deleted");
        debugPrint(tag);
        if (id is T) {
          await Future.sync(() => onDelete(id));
        }
        break;
      case ImageOptions.setMain:
        debugPrint("image set to be main");
        if (id is T) {
          await Future.sync(() => onStar(id));
        }
        break;
      case ImageOptions.share:
        debugPrint("image shared");
        if (id is T) {
          await Future.sync(() => onShare(id));
        }
        break;
      case null:
        // dialog dismissed
        break;
    }
  }

//could be extracted into an standalone widget..
  SimpleDialogOption _option(
      {required BuildContext context,
      Icon icon = const Icon(Icons.circle),
      required String description,
      ImageOptions? returnCase}) {
    return SimpleDialogOption(
      onPressed: () {
        Navigator.pop(context, returnCase);
      },
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(description),
            icon,
          ],
        ),
      ),
    );
  }
}

enum ImageOptions {
  delete,
  setMain,
  share,
  //XXX: mehr?
}

class FittedImageContainer extends StatelessWidget {
  const FittedImageContainer({
    Key? key,
    required this.item,
    this.fit = BoxFit.cover,
    required this.approxWidth,
  }) : super(key: key);

  final ImageItem item;
  final BoxFit fit;
  final num approxWidth;

  // ImageData? get img => item.image;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      builder: (context, child) => FutureBuilder<Image?>(
          future: item.image?.fullImage(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              SchedulerBinding.instance
                  .addPostFrameCallback((_) => item.markCorrupt());
              return item.fallBackWidget;
            }
            final img = snapshot.data ?? item.image?.image;
            if (img == null) {
              return LoadingView();
            }
            return Image(
              image: img.image,
              fit: fit,
              filterQuality: img.filterQuality,
              isAntiAlias: img.isAntiAlias,
              gaplessPlayback: img.gaplessPlayback,
              errorBuilder: (context, error, stackTrace) {
                SchedulerBinding.instance
                    .addPostFrameCallback((_) => item.markCorrupt());
                return item.fallBackWidget;
              },
            );
          }),
      animation: item,
    );
  }
}
