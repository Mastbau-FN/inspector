import 'package:flutter/material.dart';
import 'package:mastbau_inspector/classes/checkcategory.dart';
import 'package:mastbau_inspector/classes/inspection_location.dart';
import 'package:mastbau_inspector/fragments/MainDrawer.dart';
import 'package:mastbau_inspector/widgets/MyListTile1.dart';
import 'package:mastbau_inspector/widgets/myExpandablelList.dart';
import 'package:provider/provider.dart';

import 'checkcategoriesModel.dart';

class CategoriesView extends StatelessWidget {
  final InspectionLocation location;
  const CategoriesView({required this.location, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(
            onPressed: Navigator.of(context).pop,
          ),
          title: Text('$location'),
        ),
        endDrawer: MainDrawer(),
        body: FutureBuilder<List<CheckCategory>>(
            future: Provider.of<CategoryModel>(context).all,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done) {
                return ExpandablesListRadio(
                    children: snapshot.data!
                        .map((e) => locationDropDown(e, context))
                        .toList());
              }
              return ExpandablesListRadio.fake(3);
            }),
      ),
    );
  }

  ExpandableCard2 locationDropDown(CheckCategory cat, BuildContext context) {
    return ExpandableCard2(
        title: 'TODO', //TODO
        children: CategoryNext.values
            .map((e) => MyCardListTile1(
                  text: e.name ?? '',
                  onTap: () => e.open(context, cat),
                ))
            .toList());
  }
}
