import 'package:flutter/material.dart';
import 'package:mastbau_inspector/pages/dropdown/dropdownPage.dart';

import 'locationModel.dart';

class LocationView extends StatelessWidget {
  const LocationView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DropDownPage<LocationModel>();
  }
}
