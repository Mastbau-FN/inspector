import 'package:MBG_Inspektionen/backend/api.dart';
import 'package:MBG_Inspektionen/classes/data/inspection_location.dart';
import 'package:MBG_Inspektionen/classes/user.dart';
import 'package:MBG_Inspektionen/helpers/toast.dart';
import 'package:MBG_Inspektionen/widgets/error.dart';
import 'package:MBG_Inspektionen/widgets/trashbutton.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:MBG_Inspektionen/classes/data/checkcategory.dart';
import 'package:MBG_Inspektionen/fragments/MainDrawer.dart';
import 'package:MBG_Inspektionen/widgets/MyListTile1.dart';
import 'package:MBG_Inspektionen/widgets/myExpandablelList.dart';

import 'package:provider/provider.dart';

import '../classes/dropdownClasses.dart';
import '../generated/l10n.dart';

// XXX get to new page with hero transition

/// this builds the main layout from all the pages fully automatically
/// example usage:
/// ```
/// DropDownPage<CategoryModel>();
/// ```
/// this will create the page for choosing the next [CheckCategory]
/// the given model must implement [DropDownModel]!
class DropDownPage<
        ChildData extends WithLangText,
        ParentData extends WithOffline?,
        DDModel extends DropDownModel<ChildData, ParentData>>
    extends StatelessWidget {
  const DropDownPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<DDModel>(
      builder: (context, ddmodel, child) => Scaffold(
        appBar: AppBar(
          leading: (ModalRoute.of(context)?.canPop ?? false)
              ? BackButton(
                  onPressed: Navigator.of(context).pop,
                )
              : null,
          title: Text(ddmodel.title),
        ),
        endDrawer: MainDrawer(
          showUpload: typeOf<ChildData>() ==
              typeOf<InspectionLocation>(), //we are in the top level
          // children: ddmodel.drawerchildren,
        ),
        body: _DropDownBody<ChildData, ParentData, DDModel>(
          ddmodel: ddmodel,
        ),
        floatingActionButton: ddmodel.floatingActionButton,
      ),
    );
  }
}

class _DropDownBody<
        ChildData extends WithLangText,
        ParentData extends WithOffline?,
        DDModel extends DropDownModel<ChildData, ParentData>>
    extends StatefulWidget {
  final DDModel ddmodel;
  const _DropDownBody({
    required this.ddmodel,
    Key? key,
  }) : super(key: key);

  @override
  State<_DropDownBody<ChildData, ParentData, DDModel>> createState() =>
      _DropDownBodyState<ChildData, ParentData, DDModel>();
}

class _DropDownBodyState<
        ChildData extends WithLangText,
        ParentData extends WithOffline?,
        DDModel extends DropDownModel<ChildData, ParentData>>
    extends State<_DropDownBody<ChildData, ParentData, DDModel>> {
  // ignore: unused_field
  Future<List<ChildData>>? _future;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    _future = Provider.of<DDModel>(context, listen: false).all.last;
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DDModel>(builder: (context, ddmodel, child) {
      return FutureBuilder<List<ChildData>>(
        future: ddmodel.all.last,
        builder: (context, snapshot) => RefreshIndicator(
          onRefresh: _refresh,
          child: _list(snapshot, context),
        ),
      );
    });
  }

  Future<void> _refresh() async {
    // try {
    await __refresh().last;
    // } catch (e) {}
  }

  Stream<bool> __refresh() async* {
    await for (var freshall
        in Provider.of<DDModel>(context, listen: false).all) {
      setState(() {
        // _future = Future.value(freshall);
      });
      yield true;
    }
  }

  Widget _list(AsyncSnapshot<List<ChildData>> snapshot, BuildContext context) {
    if (snapshot.connectionState != ConnectionState.waiting) {
      return ListView(
        children: [
          if (snapshot.hasError)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: ErrorText(S.of(context).somethingWentWrong +
                    ':\n${snapshot.error ?? ''} \n\n' +
                    S.of(context).pleaseDragDownToReloadThisPage),
              ),
            ),
          if (snapshot.hasData)
            Opacity(
              opacity:
                  snapshot.connectionState != ConnectionState.done ? 0.5 : 1,
              child: ExpandablesListRadio(
                  children: snapshot.data!
                      .map((e) => dropDown_element(e, context, widget.ddmodel))
                      .toList()),
            ),
        ],
      );
    }
    return ExpandablesListRadio.fake(3);
  }

  Widget offlineIndicator(ChildData data) {
    try {
      if ((data as WithOffline).forceOffline)
        return Icon(
          Icons.cloud_off,
          color: Colors.green,
          size: 20,
        );
    } catch (e) {}
    return Container();
  }

  // ignore: non_constant_identifier_names
  ExpandableCard2 dropDown_element(
      ChildData data, BuildContext context, DDModel ddmodel) {
    return ExpandableCard2(
        previewImg: data.previewImage,
        title: data.title,
        subtitle: data.subtitle,
        extra: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            data.extra ?? Container(),
            FutureBuilder(
              future: API().user,
              builder:
                  (BuildContext context, AsyncSnapshot<DisplayUser?> snapshot) {
                //assert(data.runtimeType==DataT);
                try {
                  if (snapshot.hasData &&
                      data.toJson()['Autor'] == snapshot.data?.name)
                    return TrashButton(
                      delete: () => API()
                          .delete<ChildData>(data, caller: ddmodel.currentData)
                          .then((value) => value != null
                              ? (kDebugMode ? showToast(value) : (_) {})
                              : showToast(S.of(context).deleteUnseccessful)),
                      confirmName: data.title,
                    );
                } catch (e) {}
                return Container();
              },
            ),
            offlineIndicator(data),
          ],
        ),
        children: ddmodel.actions
            .map((actionTileData) => MyCardListTile1(
                  text: actionTileData.title,
                  icon: actionTileData.icon,
                  onTap: () => ddmodel.open(context, data, actionTileData),
                ))
            .toList());
  }
}
