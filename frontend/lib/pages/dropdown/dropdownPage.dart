import 'package:flutter/material.dart';
import 'package:mastbau_inspector/classes/data/checkcategory.dart';
import 'package:mastbau_inspector/fragments/MainDrawer.dart';
import 'package:mastbau_inspector/widgets/MyListTile1.dart';
import 'package:mastbau_inspector/widgets/myExpandablelList.dart';
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
    return Container(
      child: Consumer<DDModel>(
        builder: (context, ddmodel, child) => Scaffold(
          appBar: AppBar(
            /*leading: BackButton(
              onPressed: Navigator.of(context).pop,
            ),*/
            title: Text(ddmodel.title),
          ),
          endDrawer: MainDrawer(),
          body: FutureBuilder<List>(
              future: Provider.of<DDModel>(context).all,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done) {
                  return ExpandablesListRadio(
                      children: snapshot.data!
                          .map((e) => locationDropDown(e, context, ddmodel))
                          .toList());
                }
                return ExpandablesListRadio.fake(3);
              }),
        ),
      ),
    );
  }

  ExpandableCard2 locationDropDown(
      Data data, BuildContext context, DDModel ddmodel) {
    return ExpandableCard2(
        title: data.title, //TODO
        children: ddmodel.actions
            .map((actionTileData) => MyCardListTile1(
                  text: actionTileData.title,
                  onTap: () => ddmodel.open(context, data, actionTileData),
                ))
            .toList());
  }
}
