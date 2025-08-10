import 'package:MBG_Inspektionen/classes/data/inspection_location.dart';
import 'package:MBG_Inspektionen/pages/dropDownPageB.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:MBG_Inspektionen/pages/dropdownPage.dart';
import 'package:MBG_Inspektionen/pages/location.dart';

class HomeView extends StatelessWidget {
  final String title;
  const HomeView({required this.title, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      child: LocationView(),
    );
  }
}

/// similar to [CategoryView] but one level above (choose the [InspectionLocation])
class LocationView extends StatelessWidget {
  const LocationView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DropDownPageB<InspectionLocation, Null, LocationModel>();
  }
}
