import 'package:flutter/material.dart';
import 'package:mastbau_inspector/classes/data/inspection_location.dart';
import 'package:mastbau_inspector/pages/dropdown/dropdownPage.dart';

import 'locationModel.dart';

/// similar to [CategoryView] but one level above (choose the [InspectionLocation])
class LocationView extends StatelessWidget {
  const LocationView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DropDownPage<LocationModel>();
  }
}
