import 'package:flutter/material.dart';
import 'package:mastbau_inspector/classes/data/checkcategory.dart';
import 'package:mastbau_inspector/classes/data/checkpoint.dart';
import 'package:mastbau_inspector/pages/dropdown/dropdownPage.dart';

import 'checkpointsModel.dart';

/// for choosing the [CheckPoint] for the current [CheckCategory]
class CheckPointsView extends StatelessWidget {
  const CheckPointsView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DropDownPage<CheckPointsModel>();
  }
}
