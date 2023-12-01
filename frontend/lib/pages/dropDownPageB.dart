import 'dart:math';
import 'dart:ui';

import 'package:MBG_Inspektionen/backend/api.dart';
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
import 'package:MBG_Inspektionen/widgets/MyListTile1.dart';
import 'package:MBG_Inspektionen/widgets/error.dart';
import 'package:MBG_Inspektionen/widgets/trashbutton.dart';
import 'package:blur/blur.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
          leadingActions: [
            (context, expandRatio, barHeight, overlapsContent) => Container(
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
                        color: Theme.of(context)
                            .colorScheme
                            .surface
                            .withOpacity(0.5),
                        height: barHeight - 20,
                        child: (ModalRoute.of(context)?.canPop ?? false)
                            ? BackButton(
                                onPressed: Navigator.of(context).pop,
                              )
                            : Container(),
                      ),
                    ),
                  ),
                ),
          ],
          trailingActions: [
            (context, expandRatio, barHeight, overlapsContent) =>
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
                        color: Theme.of(context)
                            .colorScheme
                            .surface
                            .withOpacity(0.5),
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
                ),
          ],
          // // floating: true,
          // centerTitle: true,
          pinned: true,
          // snap: true,
          // expandedHeight: _appbarHeightBig,
          contentBuilder:
              (context, expandRatio, contentHeight, overlapsContent, isPinned) {
            return FutureBuilder(
              future: ddmodel.currentData?.previewImage,
              builder: (context, snapshot) {
                final img = snapshot.data?.thumbnail
                    .image; //todo show as bg (and switch to fullsize when loaded)
                return FutureBuilder(
                    future: snapshot.data?.fullImageGetter?.call(),
                    builder: (context, fullImageSnapshot) {
                      return Container(
                        decoration: BoxDecoration(
                          boxShadow: [
                            if (img != null)
                              BoxShadow(
                                color: Colors.black.withOpacity(0.5),
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
                              //background image
                              if (img != null)
                                Positioned.fill(
                                  child: fullImageSnapshot.data != null
                                      ? Image(
                                          image: fullImageSnapshot.data!.image,
                                          fit: BoxFit.cover,
                                        )
                                      : Blur(
                                          blurColor: Colors.transparent,
                                          child: Positioned.fill(
                                            child: Hero(
                                              tag: ddmodel.title +
                                                  ".image" +
                                                  ddmodel
                                                      .currentData.runtimeType
                                                      .toString(),
                                              child: Image(
                                                image: img,
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                          ),
                                        ),
                                ),
                              //title
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
                                    // padding: EdgeInsets.only(top: _appbarBarHeight),
                                    height: expandRatio >
                                            _appbarExpansionSwitchValue
                                        ? _appbarHeightBig
                                        : _appbarHeightSmall,
                                    // color: Colors.amber,
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
                                          borderRadius:
                                              BorderRadius.circular(25),
                                          child: Container(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .surface
                                                .withOpacity(0.5),
                                            // alignment: Alignment.center,
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 25,
                                              vertical: 10 * expandRatio,
                                            ),
                                            //blur background

                                            child: BackdropFilter(
                                              filter: ImageFilter.blur(
                                                sigmaX: 5,
                                                sigmaY: 5,
                                              ),
                                              child: Hero(
                                                tag: ddmodel.title +
                                                    ".title.text" +
                                                    ddmodel
                                                        .currentData.runtimeType
                                                        .toString() +
                                                    'disabled', //FIXME: mir gefiel die animation nicht, deshalb falscher tag zum disablen
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
                              //maengelbutton
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
                    });
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
                            child: ErrorText(S.of(context).somethingWentWrong +
                                ':\n${snapshot.error ?? ''} \n\n' +
                                S.of(context).pleaseDragDownToReloadThisPage),
                          ),
                        ),
                      );
                    }
                    final childrenData = snapshot.data as List<ChildData>;
                    return SliverList.list(
                      children: childrenData.map((cd) {
                        return DropDownElementB(
                          cd: cd,
                          actions: ddmodel.actions,
                          onAction: (actionTileData) {
                            ddmodel.open(context, cd, actionTileData);
                          },
                          onDelete: () => API()
                              .delete<ChildData>(cd,
                                  caller: ddmodel.currentData)
                              .then((value) => value != null
                                  ? () {
                                      (kDebugMode ? showToast(value) : (_) {});
                                      ddmodel.refresh(); //quickfix for #336
                                    }()
                                  : showToast(
                                      S.of(context).deleteUnseccessful)),
                        );
                      }).toList(),
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
  }
}

class DropDownElementB<ChildData extends WithLangText> extends StatelessWidget {
  final ChildData cd;
  final List<MyListTileData> actions;
  final Function(MyListTileData actionTileData) onAction;
  final Future Function() onDelete;

  static Future _onDelete() async {}

  const DropDownElementB({
    super.key,
    required this.cd,
    required this.actions,
    required this.onAction,
    this.onDelete = _onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      // height: 50,
      // color: // random
      //     Colors.primaries[childrenData.indexOf(cd) %
      //         Colors.primaries.length],
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
        child: TextButton(
          style: TextButton.styleFrom(
            iconColor: Theme.of(context).colorScheme.onSurface,
            // primary: Theme.of(context).colorScheme.onSurface,
            backgroundColor: Theme.of(context).colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            padding: EdgeInsets.all(0),
          ),
          onPressed: () {
            onAction(actions.first);
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
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
                        tag: cd.title +
                            ".title.text" +
                            cd.runtimeType.toString(),
                        child: Text(
                          cd.title,
                          style: Theme.of(context).textTheme.titleMedium,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
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
                                  cd.toJson()['Autor'] == snapshot2.data?.name))
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
              if (actions.length > 1)
                Row(
                  children: actions.indexed.map<Widget>((a) {
                    final (int i, MyListTileData actionTileData) = a;
                    if (i == 0) return Container();
                    return Expanded(
                      // width: 100,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 10, horizontal: 10),
                        child: MyCardListTileB(
                          text: actionTileData.title,
                          icon: actionTileData.icon,
                          onTap: () => onAction(actionTileData),
                        ),
                      ),
                    );
                  }).toList(),
                )
              else
                SizedBox(height: 5),
            ],
          ),
        ),
      ),
    );
  }
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
        alignment: Alignment.centerLeft,
        padding: EdgeInsets.all(15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      onPressed: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon),
          SizedBox(width: 10),
          Text(text),
          Spacer(),
          Icon(Icons.chevron_right,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
        ],
      ),
    );
  }
}

class PreviewImageCircle extends StatelessWidget {
  const PreviewImageCircle({
    super.key,
    required this.previewImage,
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
              var imagep = snapshot.data?.thumbnail.image;
              return (imagep != null
                      ? Image(image: imagep, fit: BoxFit.fill)
                      : null) ??
                  Icon(
                    Icons.construction,
                  );
            }),
      ),
    );
  }
}
