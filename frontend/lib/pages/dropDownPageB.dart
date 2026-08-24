import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:MBG_Inspektionen/backend/api.dart';
import 'package:MBG_Inspektionen/backend/categoryProgressState.dart';
import 'package:MBG_Inspektionen/backend/sync_events.dart';
import 'package:MBG_Inspektionen/classes/data/checkcategory.dart';
import 'package:MBG_Inspektionen/classes/data/checkpoint.dart';
import 'package:MBG_Inspektionen/classes/data/checkpointdefect.dart';
import 'package:MBG_Inspektionen/classes/data/inspection_location.dart';
import 'package:MBG_Inspektionen/classes/dropdownClasses.dart';
import 'package:MBG_Inspektionen/classes/imageData.dart';
import 'package:MBG_Inspektionen/classes/listTileData.dart';
import 'package:MBG_Inspektionen/classes/user.dart';
import 'package:MBG_Inspektionen/fragments/MainDrawer.dart';
import 'package:MBG_Inspektionen/helpers/toast.dart';
import 'package:MBG_Inspektionen/l10n/locales.dart';
import 'package:MBG_Inspektionen/pages/checkpointdefects.dart';
import 'package:MBG_Inspektionen/pages/dropdownPage.dart';
import 'package:MBG_Inspektionen/widgets/error.dart';
import 'package:blur/blur.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sliver_app_bar_builder/sliver_app_bar_builder.dart';

extension Add on double? {
  double? operator +(double other) => this != null ? this! + other : null;
}

class DropDownPageB<
        ChildData extends WithLangText,
        ParentData extends WithOffline?,
        DDModel extends DropDownModel<ChildData, ParentData>>
    extends StatelessWidget {
  const DropDownPageB({Key? key}) : super(key: key);

  static final Set<String> _primingCategoryIds = <String>{};
  static Future<void> _categoryPrimingTail = Future<void>.value();

  static const _appbarHeightSmall = 70.0;
  static const _appbarBarHeight = 70.0;
  static const _appbarHeightBig = 260.0;
  static const _appbarExpansionSwitchValue = 0.9;

  @override
  Widget build(BuildContext context) {
    return Consumer<DDModel>(
      builder: (context, ddmodel, child) {
        return ValueListenableBuilder<int>(
          valueListenable: SyncEvents.instance.revision,
          builder: (context, syncRevision, _) {
            final childrenFuture = ddmodel.allCached(syncRevision);
            final maengelDoneButton = ddmodel.runtimeType ==
                    CheckPointDefectsModel
                ? Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    child:
                        (ddmodel as CheckPointDefectsModel).ohneMaengelButton(
                      context,
                      defectsFuture: childrenFuture.then(
                        (children) =>
                            children.whereType<CheckPointDefect>().toList(),
                      ),
                    ),
                  )
                : Container();

            final sliverAppBar = SliverAppBarBuilder(
              barHeight:
                  // Theme.of(context).appBarTheme.toolbarHeight ??
                  _appbarBarHeight,
              initialBarHeight: _appbarBarHeight,
              initialContentHeight: _appbarHeightBig,
              backgroundColorAll: Theme.of(context).colorScheme.surface,
              contentBelowBar: false,
              // forceMaterialTransparency: true,
              // primary: true,
              leadingActions: [backButtonW],
              trailingActions: [drawerButtonW],
              // // floating: true,
              // centerTitle: true,
              pinned: true,
              // snap: true,
              // expandedHeight: _appbarHeightBig,
              contentBuilder: (context, expandRatio, contentHeight,
                  overlapsContent, isPinned) {
                return FutureBuilder<ImageData?>(
                  future: ddmodel.currentData?.previewImage,
                  builder: (context, snapshot) {
                    final img = snapshot.data?.image.image;
                    final currentData = ddmodel.currentData;
                    final currentDataId =
                        currentData == null ? "root" : (currentData as Data).id;
                    return Container(
                      decoration: BoxDecoration(
                        boxShadow: [
                          if (img != null)
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.5),
                              blurRadius: 20,
                              spreadRadius: 5,
                              offset: Offset(0, 5),
                            ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(25 * expandRatio),
                          bottomRight: Radius.circular(25 * expandRatio),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // background image
                            if (img != null)
                              Positioned.fill(
                                child: Blur(
                                  blurColor: Colors.transparent,
                                  child: Positioned.fill(
                                    child: Hero(
                                      tag:
                                          "dropdown.header.image.${ddmodel.currentData.runtimeType}.$currentDataId",
                                      child: Image(
                                        image: ResizeImage.resizeIfNeeded(
                                          (MediaQuery.sizeOf(context).width *
                                                  MediaQuery.devicePixelRatioOf(
                                                    context,
                                                  ))
                                              .ceil()
                                              .clamp(1, 4096)
                                              .toInt(),
                                          null,
                                          img,
                                        ),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            // title
                            Container(
                              alignment: Alignment.center,
                              height: contentHeight,
                              padding: EdgeInsets.only(
                                left: 10 + (1 - expandRatio) * 40,
                                right: 10 + (1 - expandRatio) * 40,
                                bottom: 10,
                                top: 10 + (expandRatio) * _appbarBarHeight,
                              ),
                              child: SafeArea(
                                child: AnimatedContainer(
                                  height:
                                      expandRatio > _appbarExpansionSwitchValue
                                          ? _appbarHeightBig
                                          : _appbarHeightSmall,
                                  alignment: Alignment.center,
                                  curve: Curves.fastOutSlowIn,
                                  duration: const Duration(milliseconds: 200),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10),
                                    child: Container(
                                      decoration: img == null
                                          ? null
                                          : BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(27),
                                              border: Border.all(
                                                color: Colors.white,
                                                width: 2,
                                              ),
                                            ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(25),
                                        child: Container(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .surface
                                              .withValues(alpha: 0.5),
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 25,
                                            vertical: 10 * expandRatio,
                                          ),
                                          child: BackdropFilter(
                                            filter: ImageFilter.blur(
                                              sigmaX: 5,
                                              sigmaY: 5,
                                            ),
                                            child: Hero(
                                              tag:
                                                  "dropdown.header.title.${ddmodel.currentData.runtimeType}.$currentDataId.disabled",
                                              child: Text(
                                                ddmodel.title,
                                                overflow: expandRatio >
                                                        _appbarExpansionSwitchValue
                                                    ? null
                                                    : TextOverflow.ellipsis,
                                                softWrap: true,
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  fontSize: Theme.of(context)
                                                          .textTheme
                                                          .headlineMedium
                                                          ?.fontSize +
                                                      expandRatio * 5,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onSurface,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // maengel button
                            Positioned(
                              top: MediaQuery.of(context).padding.top *
                                  (4 * expandRatio - 3),
                              height: _appbarBarHeight,
                              child: Opacity(
                                opacity: max(expandRatio * 2 - 1, 0),
                                child: Align(child: maengelDoneButton),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            );
            return Scaffold(
              body: RefreshIndicator(
                onRefresh: () async {
                  ddmodel.refresh();
                },
                child: CustomScrollView(
                  // physics: BouncingScrollPhysics(),
                  slivers: <Widget>[
                    sliverAppBar,
                    FutureBuilder(
                      future: childrenFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return SliverFillRemaining(
                            child: Center(
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }
                        if (snapshot.hasError) {
                          return SliverFillRemaining(
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: ErrorText(
                                    S.of(context).somethingWentWrong +
                                        ':\n${snapshot.error ?? ''} \n\n' +
                                        S
                                            .of(context)
                                            .pleaseDragDownToReloadThisPage),
                              ),
                            ),
                          );
                        }
                        final childrenData = snapshot.data as List<ChildData>;
                        _updateCurrentCategoryTotal(ddmodel, childrenData);
                        _primeCategoryTotals(childrenData);
                        if (ddmodel.runtimeType == CheckPointDefectsModel) {
                          return generateCheckPointDefectsSliverList(
                              context, childrenData as List<CheckPointDefect>);
                        }
                        return ValueListenableBuilder<int>(
                          valueListenable:
                              CategoryProgressState.instance.revision,
                          builder: (context, _, __) {
                            return SliverList.list(
                              children: childrenData.map((cd) {
                                final progressEntry = cd is CheckCategory
                                    ? CategoryProgressState.instance
                                        .entryFor(cd.id)
                                    : null;
                                final checkpointCompleted = cd is CheckPoint &&
                                    CategoryProgressState.instance
                                        .checkpointCompleted(
                                      checkpointId: cd.id,
                                      pjNr: cd.pjNr,
                                      categoryIndex: cd.category_index,
                                      checkpointIndex: cd.index,
                                    );
                                final totalCheckpoints = cd is CheckCategory
                                    ? (progressEntry?.totalCheckpoints ??
                                        CategoryProgressState.instance
                                            .totalFor(cd.id))
                                    : null;
                                final completionPercent = checkpointCompleted
                                    ? 1.0
                                    : progressEntry?.progress ?? 0.0;
                                final completionLabel = totalCheckpoints == null
                                    ? null
                                    : '${progressEntry?.completedCheckpoints ?? 0}/$totalCheckpoints bearbeitet';

                                return DropDownElementB(
                                  cd: cd,
                                  completionPercent: completionPercent,
                                  completionLabel: completionLabel,
                                  actions: ddmodel.actions,
                                  onAction: (actionTileData) {
                                    ddmodel.open(context, cd, actionTileData);
                                  },
                                  onDelete: () async {
                                    final value = await API().delete<ChildData>(
                                      cd,
                                      caller: ddmodel.currentData,
                                    );
                                    if (value == null) {
                                      showToast(
                                        S.of(context).deleteUnseccessful,
                                      );
                                      return;
                                    }
                                    if (kDebugMode) showToast(value);
                                    final parent = ddmodel.currentData;
                                    if (cd is CheckPoint &&
                                        parent is CheckCategory) {
                                      CategoryProgressState.instance
                                          .checkpointRemoved(
                                        categoryId: parent.id,
                                        checkpointId: cd.id,
                                        pjNr: cd.pjNr,
                                        categoryIndex: cd.category_index,
                                        checkpointIndex: cd.index,
                                      );
                                    }
                                    ddmodel.refresh(); //quickfix for #336
                                  },
                                );
                              }).toList(),
                            );
                          },
                        );
                      },
                    ),
                    SliverToBoxAdapter(
                      child: SizedBox(height: 30),
                    )
                  ],
                ),
              ),
              endDrawer: MainDrawer(
                showUpload: typeOf<ChildData>() ==
                    typeOf<InspectionLocation>(), //we are in the top level
                // children: ddmodel.drawerchildren,
              ),
              floatingActionButton: ddmodel.floatingActionButton(context),
            );
          },
        );
      },
    );
  }

  Widget drawerButtonW(context, expandRatio, barHeight, overlapsContent) =>
      //Open drawer
      Container(
        height: barHeight,
        alignment: Alignment.centerLeft,
        child: ClipRRect(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(25),
            bottomLeft: Radius.circular(25),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: Container(
              alignment: Alignment.centerLeft,
              color:
                  Theme.of(context).colorScheme.surface.withValues(alpha: 0.5),
              height: barHeight - 20,
              child: IconButton(
                icon: Icon(Icons.menu),
                onPressed: () {
                  Scaffold.of(context).openEndDrawer();
                },
              ),
            ),
          ),
        ),
      );

  Widget backButtonW(context, expandRatio, barHeight, overlapsContent) =>
      Container(
        height: barHeight,
        alignment: Alignment.centerLeft,
        child: ClipRRect(
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(25),
            bottomRight: Radius.circular(25),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: Container(
              alignment: Alignment.centerLeft,
              color:
                  Theme.of(context).colorScheme.surface.withValues(alpha: 0.5),
              height: barHeight - 20,
              child: (ModalRoute.of(context)?.canPop ?? false)
                  ? BackButton(
                      onPressed: Navigator.of(context).pop,
                    )
                  : Container(),
            ),
          ),
        ),
      );

  void _primeCategoryTotals(List<ChildData> childrenData) {
    final categories = childrenData.whereType<CheckCategory>();
    for (final category in categories) {
      if (CategoryProgressState.instance.totalFor(category.id) != null) {
        continue;
      }
      if (!_primingCategoryIds.add(category.id)) {
        continue;
      }
      final work = _categoryPrimingTail.then<void>((_) async {
        if (CategoryProgressState.instance.totalFor(category.id) != null) {
          return;
        }
        final checkpointCount = await API().local.countNextDatapoints(category);
        CategoryProgressState.instance.registerCategory(
          categoryId: category.id,
          pjNr: category.pjNr,
          categoryIndex: category.index,
          totalCheckpoints: checkpointCount,
        );
      });
      final guarded = work.catchError((Object error, StackTrace stackTrace) {
        debugPrint(
          'Prüfpunktanzahl für ${category.id} konnte nicht gelesen werden: '
          '$error',
        );
      });
      _categoryPrimingTail = guarded;
      unawaited(guarded.whenComplete(() {
        _primingCategoryIds.remove(category.id);
      }));
    }
  }

  void _updateCurrentCategoryTotal(
    DDModel model,
    List<ChildData> childrenData,
  ) {
    final category = model.currentData;
    if (category is! CheckCategory ||
        childrenData.any((child) => child is! CheckPoint)) {
      return;
    }
    final total = childrenData.length;
    if (CategoryProgressState.instance.totalFor(category.id) == total) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (CategoryProgressState.instance.totalFor(category.id) == total) {
        return;
      }
      CategoryProgressState.instance.registerCategory(
        categoryId: category.id,
        pjNr: category.pjNr,
        categoryIndex: category.index,
        totalCheckpoints: total,
      );
    });
  }
}

class DropDownElementB<ChildData extends WithLangText> extends StatelessWidget {
  final ChildData cd;
  final double completionPercent;
  final String? completionLabel;
  final List<MyListTileData> actions;
  final Function(MyListTileData actionTileData) onAction;
  final Future Function() onDelete;

  static Future _onDelete() async {}

  const DropDownElementB({
    super.key,
    required this.cd,
    this.completionPercent = 0,
    this.completionLabel,
    required this.actions,
    required this.onAction,
    this.onDelete = _onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final progress = completionPercent.clamp(0.0, 1.0);
    final showCompletion =
        (cd is CheckCategory || cd is CheckPoint) && progress > 0;
    final showCompletionLabel = cd is CheckCategory && completionLabel != null;
    const progressColor = Color(0xFF2E7D32);

    return Container(
      // height: 50,
      // color: // random
      //     Colors.primaries[childrenData.indexOf(cd) %
      //         Colors.primaries.length],
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
        child: TextButton(
          clipBehavior: Clip.antiAlias,
          style: TextButton.styleFrom(
            iconColor: Theme.of(context).colorScheme.onSurface,
            // primary: Theme.of(context).colorScheme.onSurface,
            backgroundColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            padding: EdgeInsets.all(0),
          ),
          onPressed: () {
            onAction(actions.first);
          },
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),
              if (showCompletion)
                Positioned.fill(
                  key: Key('dropdown.completion.${cd.id}'),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final overlayWidth = constraints.maxWidth * progress;
                      final reachedEnd = progress >= 0.999;

                      return Align(
                        alignment: Alignment.centerLeft,
                        child: SizedBox(
                          width: overlayWidth,
                          height: constraints.maxHeight,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: progressColor.withValues(alpha: 0.45),
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(15),
                                bottomLeft: Radius.circular(15),
                                topRight: Radius.circular(reachedEnd ? 15 : 0),
                                bottomRight:
                                    Radius.circular(reachedEnd ? 15 : 0),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  (cd is InspectionLocation)
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ExpansionTile(
                              title: Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(10, 10, 10, 5),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 50,
                                      child: PreviewImageCircle(
                                        previewImage: cd.previewImage,
                                      ),
                                    ),
                                    offlineIndicator(cd),
                                    Expanded(
                                      child: Hero(
                                        key: Key('dropdown.title.${cd.id}'),
                                        tag:
                                            "dropdown.item.title.${cd.runtimeType}.${cd.id}",
                                        child:
                                            dropdownItemTitleText(context, cd),
                                      ),
                                    ),
                                    ...cd.extras(context: context),
                                  ],
                                ),
                              ),
                              children: [
                                if (actions.length > 1)
                                  Row(
                                    children: actions.indexed.map<Widget>((a) {
                                      final (
                                        int i,
                                        MyListTileData actionTileData
                                      ) = a;
                                      if (i == 0) return Container();

                                      final int totalTiles = actions.length;
                                      final bool isBeforeLastThree =
                                          i >= totalTiles - 4 &&
                                              i < totalTiles - 1;
                                      final int flexValue =
                                          isBeforeLastThree ? 2 : 3;

                                      return Expanded(
                                        flex: flexValue,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 10, horizontal: 5),
                                          child: MyCardListTileB(
                                            text: actionTileData.title,
                                            icon: actionTileData.icon,
                                            onTap: () =>
                                                onAction(actionTileData),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  )
                                else
                                  SizedBox(height: 5),
                              ],
                            ),
                            InspectionDownloadProgressPanel(
                              location: cd as InspectionLocation,
                            ),
                          ],
                        )
                      : Padding(
                          padding: const EdgeInsets.fromLTRB(10, 10, 10, 5),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: 50,
                                    child: PreviewImageCircle(
                                      previewImage: cd.previewImage,
                                    ),
                                  ),
                                  offlineIndicator(cd),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.only(
                                        left: 4,
                                        top: 6,
                                        bottom: 6,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Hero(
                                            key: Key('dropdown.title.${cd.id}'),
                                            tag:
                                                "dropdown.item.title.${cd.runtimeType}.${cd.id}",
                                            child: dropdownItemTitleText(
                                              context,
                                              cd,
                                            ),
                                          ),
                                          if (showCompletionLabel) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              key: Key(
                                                'dropdown.progress-label.${cd.id}',
                                              ),
                                              completionLabel!,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .labelSmall
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _DropDownItemMenu<ChildData>(
                                          key: Key(
                                            'dropdown.actions.${cd.id}',
                                          ),
                                          data: cd,
                                          actions: actions,
                                          onAction: onAction,
                                          onDelete: onDelete,
                                        ),
                                        Transform.translate(
                                          offset: const Offset(4, 0),
                                          child: Icon(
                                            actions.first.icon,
                                            size: 10,
                                          ),
                                        ),
                                        const Icon(Icons.chevron_right),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                  // SizedBox(height: 10),
                  //secondRow
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _DropDownItemCommand { edit, delete }

@visibleForTesting
bool isOwnedByUser(Data data, DisplayUser? user) {
  if (user == null || data is! WithAuthor) return false;
  final author = data.author?.trim().toLowerCase();
  final userName = user.name.trim().toLowerCase();
  return author != null && author.isNotEmpty && author == userName;
}

class _DropDownItemMenu<ChildData extends WithLangText>
    extends StatelessWidget {
  const _DropDownItemMenu({
    super.key,
    required this.data,
    required this.actions,
    required this.onAction,
    required this.onDelete,
  });

  final ChildData data;
  final List<MyListTileData> actions;
  final Function(MyListTileData) onAction;
  final Future Function() onDelete;

  bool _isOwnedBy(DisplayUser? user) {
    return isOwnedByUser(data, user);
  }

  Future<void> _edit(BuildContext context) async {
    if (data case CheckCategory category) {
      await category.openEditor(context);
    } else if (data case CheckPoint checkpoint) {
      await checkpoint.openEditor(context);
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Eintrag löschen?'),
            content: Text(
              '„${data.title}“ wird dauerhaft aus dieser Inspektion gelöscht.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(S.of(context).cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Löschen'),
              ),
            ],
          ),
        ) ??
        false;
    if (confirmed) await onDelete();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DisplayUser?>(
      future: API().user,
      builder: (context, snapshot) {
        final ownedByUser = _isOwnedBy(snapshot.data);
        final canEdit =
            ownedByUser && (data is CheckCategory || data is CheckPoint);
        final canDelete = data is CheckPointDefect || ownedByUser;
        final secondaryActions = actions.skip(1).toList(growable: false);

        if (secondaryActions.isEmpty && !canEdit && !canDelete) {
          return const SizedBox.shrink();
        }

        return PopupMenuButton<Object>(
          tooltip: 'Weitere Aktionen',
          icon: const Icon(Icons.more_vert),
          onSelected: (selection) async {
            if (selection is MyListTileData) {
              onAction(selection);
            } else if (selection == _DropDownItemCommand.edit) {
              await _edit(context);
            } else if (selection == _DropDownItemCommand.delete) {
              await _confirmDelete(context);
            }
          },
          itemBuilder: (context) => [
            for (final action in secondaryActions)
              PopupMenuItem<Object>(
                value: action,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(action.icon),
                  title: Text(action.title),
                ),
              ),
            if (canEdit)
              const PopupMenuItem<Object>(
                value: _DropDownItemCommand.edit,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.edit),
                  title: Text('Bearbeiten'),
                ),
              ),
            if (canDelete)
              const PopupMenuItem<Object>(
                value: _DropDownItemCommand.delete,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.delete),
                  title: Text('Löschen'),
                ),
              ),
          ],
        );
      },
    );
  }
}

Text dropdownItemTitleText(BuildContext context, WithLangText data) {
  final isInspection = data is InspectionLocation;
  return Text(
    data.title,
    style: Theme.of(context).textTheme.titleMedium,
    maxLines: isInspection ? 2 : null,
    overflow: isInspection ? TextOverflow.ellipsis : TextOverflow.visible,
    softWrap: true,
  );
}

class MyCardListTileB extends StatelessWidget {
  const MyCardListTileB(
      {super.key,
      required this.icon,
      required this.text,
      this.subtext,
      this.onTap});
  final IconData? icon;
  final String text;
  final String? subtext;
  final void Function()? onTap;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        alignment: Alignment.center,
        padding: EdgeInsets.fromLTRB(0, 15, 0, 15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      onPressed: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          //Icon(icon),
          //SizedBox(width: 10),
          Text(text),
          //Spacer(), Issue #385
          //Icon(Icons.chevron_right,
          //color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
        ],
      ),
    );
  }
}

class PreviewImageCircle extends StatelessWidget {
  final IconData fallbackIcon;
  const PreviewImageCircle({
    super.key,
    required this.previewImage,
    this.fallbackIcon = Icons.construction,
  });

  final Future<ImageData?> previewImage;

  @override
  Widget build(BuildContext context) {
    if (!TickerMode.of(context)) {
      return Icon(fallbackIcon);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: AspectRatio(
        aspectRatio: 1.0,
        child: FutureBuilder(
            future: previewImage,
            builder: (context, snapshot) {
              var imagep = snapshot.data?.image.image;
              return (imagep != null
                      ? Image(
                          image: ResizeImage.resizeIfNeeded(
                            (50 * MediaQuery.devicePixelRatioOf(context))
                                .ceil()
                                .clamp(1, 512)
                                .toInt(),
                            null,
                            imagep,
                          ),
                          fit: BoxFit.fill,
                          errorBuilder: (context, error, stackTrace) => Icon(
                            fallbackIcon,
                          ),
                        )
                      : null) ??
                  Icon(
                    fallbackIcon,
                  );
            }),
      ),
    );
  }
}
