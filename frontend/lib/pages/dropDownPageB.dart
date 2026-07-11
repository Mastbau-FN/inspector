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
import 'package:MBG_Inspektionen/widgets/trashbutton.dart';
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

  static const _appbarHeightSmall = 70.0;
  static const _appbarBarHeight = 70.0;
  static const _appbarHeightBig = 260.0;
  static const _appbarExpansionSwitchValue = 0.9;

  @override
  Widget build(BuildContext context) {
    return Consumer<DDModel>(
      builder: (context, ddmodel, child) {
        final maengelDoneButton = ddmodel.runtimeType == CheckPointDefectsModel
            ? Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: (ddmodel as CheckPointDefectsModel)
                    .ohneMaengelButton(context),
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
          contentBuilder:
              (context, expandRatio, contentHeight, overlapsContent, isPinned) {
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
                                    image: img,
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
                              height: expandRatio > _appbarExpansionSwitchValue
                                  ? _appbarHeightBig
                                  : _appbarHeightSmall,
                              alignment: Alignment.center,
                              curve: Curves.fastOutSlowIn,
                              duration: const Duration(milliseconds: 200),
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 10),
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
                ValueListenableBuilder<int>(
                  valueListenable: SyncEvents.instance.revision,
                  builder: (context, _, __) => FutureBuilder(
                    future: ddmodel.all().last,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
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
                              child: ErrorText(S
                                      .of(context)
                                      .somethingWentWrong +
                                  ':\n${snapshot.error ?? ''} \n\n' +
                                  S.of(context).pleaseDragDownToReloadThisPage),
                            ),
                          ),
                        );
                      }
                      final childrenData = snapshot.data as List<ChildData>;
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
                              final totalCheckpoints = cd is CheckCategory
                                  ? (progressEntry?.totalCheckpoints ??
                                      CategoryProgressState.instance
                                          .totalFor(cd.id))
                                  : null;
                              final completionPercent =
                                  progressEntry?.progress ?? 0.0;
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
                                onDelete: () => API()
                                    .delete<ChildData>(cd,
                                        caller: ddmodel.currentData)
                                    .then((value) => value != null
                                        ? () {
                                            (kDebugMode
                                                ? showToast(value)
                                                : (_) {});
                                            ddmodel
                                                .refresh(); //quickfix for #336
                                          }()
                                        : showToast(
                                            S.of(context).deleteUnseccessful)),
                              );
                            }).toList(),
                          );
                        },
                      );
                    },
                  ),
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
      unawaited(() async {
        try {
          final checkpoints = await API()
              .getNextDatapoint<CheckPoint, CheckCategory>(category)
              .last;
          CategoryProgressState.instance.setTotal(
            categoryId: category.id,
            totalCheckpoints: checkpoints.length,
          );
        } finally {
          _primingCategoryIds.remove(category.id);
        }
      }());
    }
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
    final showCompletion = cd is CheckCategory && progress > 0;
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
                                  tag:
                                      "dropdown.item.title.${cd.runtimeType}.${cd.id}",
                                  child: dropdownItemTitleText(context, cd),
                                ),
                              ),
                              if (showCompletionLabel)
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 8),
                                  child: Text(
                                    completionLabel!,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                ),
                              ...cd.extras(context: context),
                              FutureBuilder(
                                future: API().user,
                                builder: (BuildContext context,
                                    AsyncSnapshot<DisplayUser?> snapshot2) {
                                  //assert(data.runtimeType==DataT);
                                  try {
                                    if (cd.runtimeType ==
                                            CheckPointDefect //alle mängel dürfen gelöscht werden (#380)
                                        ||
                                        (snapshot2.hasData &&
                                            cd.toJson()['Autor'] ==
                                                snapshot2.data?.name))
                                      return TrashButton(
                                        delete: onDelete,
                                        confirmName: cd.title,
                                      );
                                  } catch (e) {}
                                  return Container();
                                },
                              ), // Spacer(),
                              Transform.translate(
                                offset: Offset(4, 0),
                                child: Icon(actions.first.icon, size: 10),
                              ),
                              Icon(Icons.chevron_right),
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
                          image: imagep,
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
