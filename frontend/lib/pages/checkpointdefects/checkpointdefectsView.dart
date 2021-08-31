import 'package:flutter/material.dart';
import 'package:mastbau_inspector/classes/data/checkpoint.dart';
import 'package:mastbau_inspector/classes/data/checkpointdefect.dart';
import 'package:mastbau_inspector/pages/dropdown/dropdownPage.dart';

import 'checkpointdefectsModel.dart';

/// for choosing the [CheckPointDefect] for the current [CheckPoint]
class CheckPointDefectsView extends StatelessWidget {
  const CheckPointDefectsView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DropDownPage<CheckPointDefectsModel>();
  }
}
