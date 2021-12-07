import 'package:flutter/material.dart';
import 'package:MBG_Inspektionen/classes/data/checkcategory.dart';
import 'package:MBG_Inspektionen/fragments/MainDrawer.dart';
import 'package:MBG_Inspektionen/widgets/MyListTile1.dart';
import 'package:MBG_Inspektionen/widgets/myExpandablelList.dart';
import 'package:provider/provider.dart';

import 'dropdownModel.dart';

// XXX get to new page with hero transition

/// this builds the main layout from all the pages fully automatically
/// example usage:
/// ```
/// DropDownPage<CategoryModel>();
/// ```
/// this will create the page for choosing the next [CheckCategory]
/// the given model must implement [DropDownModel]!
class DropDownPage<DDModel extends DropDownModel> extends StatelessWidget {
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
        body: _DropDownBody(
          ddmodel: ddmodel,
        ),
        floatingActionButton: ddmodel.floatingActionButton,
      ),
    );
  }
}

class _DropDownBody<DDModel extends DropDownModel> extends StatefulWidget {
  final DDModel ddmodel;
  const _DropDownBody({
    required this.ddmodel,
    Key? key,
  }) : super(key: key);

  @override
  State<_DropDownBody<DDModel>> createState() => _DropDownBodyState<DDModel>();
}

class _DropDownBodyState<DDModel extends DropDownModel>
    extends State<_DropDownBody<DDModel>> {
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
      return FutureBuilder<List>(
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

  Widget _list(AsyncSnapshot<List<dynamic>> snapshot, BuildContext context) {
    if (snapshot.connectionState == ConnectionState.done) {
      //debugPrint(snapshot.data?.length.toString());
      return ListView(
        children: [
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
      Data data, BuildContext context, DDModel ddmodel) {
    return ExpandableCard2(
        previewImg: data.previewImage,
        title: data.title,
        subtitle: data.subtitle,
        extra: data.extra,
        children: ddmodel.actions
            .map((actionTileData) => MyCardListTile1(
                  text: actionTileData.title,
                  icon: actionTileData.icon,
                  onTap: () => ddmodel.open(context, data, actionTileData),
                ))
            .toList());
  }
}
