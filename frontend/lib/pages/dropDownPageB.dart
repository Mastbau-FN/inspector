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
import 'package:MBG_Inspektionen/pages/dropdownPage.dart';
import 'package:MBG_Inspektionen/widgets/MyListTile1.dart';
import 'package:MBG_Inspektionen/widgets/error.dart';
import 'package:MBG_Inspektionen/widgets/trashbutton.dart';
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

  static const _appbarHeightSmall = 60.0;
  static const _appbarHeightBig = 160.0;
  static const _appbarExpansionSwitchValue = 0.9;

  @override
  Widget build(BuildContext context) {
    return Consumer<DDModel>(
      builder: (context, ddmodel, child) {
        var sliverAppBar = SliverAppBarBuilder(
          barHeight:
              // Theme.of(context).appBarTheme.toolbarHeight ??
              _appbarHeightSmall,
          initialBarHeight: _appbarHeightSmall,
          initialContentHeight: _appbarHeightBig,
          backgroundColorAll: Theme.of(context).colorScheme.surface,
          // forceMaterialTransparency: true,
          // primary: true,
          leadingActions: [
            (context, expandRatio, barHeight, overlapsContent) => Container(
                  height: barHeight,
                  child: (ModalRoute.of(context)?.canPop ?? false)
                      ? BackButton(
                          onPressed: Navigator.of(context).pop,
                        )
                      : Container(),
                ),
          ],
          trailingActions: [
            (context, expandRatio, barHeight, overlapsContent) =>
                //Open drawer
                Container(
                  height: barHeight,
                  child: IconButton(
                    icon: Icon(Icons.menu),
                    onPressed: () {
                      Scaffold.of(context).openEndDrawer();
                    },
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
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      alignment: Alignment.center,
                      height: contentHeight,
                      padding: EdgeInsets.symmetric(
                          horizontal: 10 + (1 - expandRatio) * 40,
                          vertical: 10),
                      child: AnimatedContainer(
                        height: expandRatio > _appbarExpansionSwitchValue
                            ? _appbarHeightBig
                            : _appbarHeightSmall,
                        // color: Colors.amber,
                        alignment: Alignment.center,
                        curve: Curves.fastOutSlowIn,
                        duration: const Duration(milliseconds: 200),
                        child: Hero(
                          tag: ddmodel.title +
                              ".title.text" +
                              ddmodel.currentData.runtimeType.toString(),
                          child: Text(
                            ddmodel.title,
                            overflow: expandRatio > _appbarExpansionSwitchValue
                                ? null
                                : TextOverflow.ellipsis,
                            softWrap: true,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: Theme.of(context)
                                      .textTheme
                                      .headlineMedium
                                      ?.fontSize +
                                  expandRatio * 10,
                              color: Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.bold,
                            ),
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
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
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
              ),
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
