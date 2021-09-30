import 'package:flutter/material.dart';
import 'package:mastbau_inspector/classes/data/inspection_location.dart';
import 'package:mastbau_inspector/classes/user.dart';
import 'package:mastbau_inspector/pages/dropdown/dropdownPage.dart';

import 'locationModel.dart';

/// similar to [CategoryView] but one level above (choose the [InspectionLocation])
class LocationView extends StatelessWidget {
  final User? user;
  const LocationView(this.user, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DropDownPage(LocationModel(user: user));
  }
}
