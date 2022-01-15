import 'package:MBG_Inspektionen/backend/api.dart';
import 'package:MBG_Inspektionen/classes/user.dart';
import 'package:MBG_Inspektionen/fragments/ErrorView.dart';
import 'package:MBG_Inspektionen/widgets/error.dart';
import 'package:MBG_Inspektionen/widgets/trashbutton.dart';
import 'package:flutter/material.dart';
import 'package:MBG_Inspektionen/classes/data/checkcategory.dart';
import 'package:MBG_Inspektionen/fragments/MainDrawer.dart';
import 'package:MBG_Inspektionen/widgets/MyListTile1.dart';
import 'package:MBG_Inspektionen/widgets/myExpandablelList.dart';
import 'package:provider/provider.dart';

import '../classes/dropdownClasses.dart';

// XXX get to new page with hero transition

/// this builds the main layout from all the pages fully automatically
/// example usage:
/// ```
/// DropDownPage<CategoryModel>();
/// ```
/// this will create the page for choosing the next [CheckCategory]
/// the given model must implement [DropDownModel]!
class DropDownPage<DataT extends Data, DDModel extends DropDownModel<DataT>>
    extends StatelessWidget {
  const DropDownPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<DDModel>(
      builder: (context, ddmodel, child) => Scaffold(
        appBar: AppBar(
          leading: Navigator.canPop(context)
              ? BackButton(
                  onPressed: Navigator.of(context).pop,
                )
              : null,
          title: Text(ddmodel.title),
        ),
        endDrawer: MainDrawer(),
        body: _DropDownBody<DataT, DDModel>(
          ddmodel: ddmodel,
        ),
        floatingActionButton: ddmodel.floatingActionButton,
      ),
    );
  }
}

class _DropDownBody<DataT extends Data, DDModel extends DropDownModel<DataT>>
    extends StatefulWidget {
  final DDModel ddmodel;
  const _DropDownBody({
    required this.ddmodel,
    Key? key,
  }) : super(key: key);

  @override
  State<_DropDownBody<DataT, DDModel>> createState() =>
      _DropDownBodyState<DataT, DDModel>();
}

class _DropDownBodyState<DataT extends Data,
        DDModel extends DropDownModel<DataT>>
    extends State<_DropDownBody<DataT, DDModel>> {
  Future<List<dynamic>>? _future;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    _future = Provider.of<DDModel>(context, listen: false).all;
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DDModel>(builder: (context, ddmodel, child) {
      return FutureBuilder<List<DataT>>(
        future: ddmodel.all,
        builder: (context, snapshot) => RefreshIndicator(
          onRefresh: _refresh,
          child: _list(snapshot, context),
        ),
      );
    });
  }

  Future<void> _refresh() async {
    List<Data> freshall =
        await Provider.of<DDModel>(context, listen: false).all;
    setState(() {
      _future = Future.value(freshall);
    });
  }

  Widget _list(AsyncSnapshot<List<DataT>> snapshot, BuildContext context) {
    if (snapshot.connectionState == ConnectionState.done) {
      return ListView(
        children: [
          if (snapshot.hasError)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: ErrorText(
                    'Something went wrong:\n${snapshot.error ?? ''} \n\nPlease drag down to reload this page'),
              ),
            ),
          if (snapshot.hasData)
            ExpandablesListRadio(
                children: snapshot.data!
                    .map((e) => dropDown_element(e, context, widget.ddmodel))
                    .toList()),
        ],
      );
    }
    return ExpandablesListRadio.fake(3);
  }

  ExpandableCard2 dropDown_element(
      DataT data, BuildContext context, DDModel ddmodel) {
    return ExpandableCard2(
        previewImg: data.previewImage,
        title: data.title,
        subtitle: data.subtitle,
        extra: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            data.extra ?? Container(),
            FutureBuilder(
              future: Backend().user,
              builder:
                  (BuildContext context, AsyncSnapshot<DisplayUser?> snapshot) {
                try {
                  if (snapshot.hasData &&
                      data.toJson()['Autor'] == snapshot.data?.name)
                    return TrashButton(
                      delete: () => Backend().delete(data),
                      confirm_name: data.title,
                    );
                } catch (e) {}
                return Container();
              },
            ),
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
