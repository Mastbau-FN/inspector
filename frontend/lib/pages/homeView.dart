import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:MBG_Inspektionen/pages/dropdown/dropdownPage.dart';
import 'package:MBG_Inspektionen/pages/locationModel.dart';

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
    return DropDownPage<LocationModel>();
  }
}
