import 'package:flutter/material.dart';
import 'package:inspector/classes/data/checkcategory.dart';
import 'package:inspector/classes/data/inspection_location.dart';
import 'package:inspector/pages/dropdown/dropdownPage.dart';

import 'checkcategoriesModel.dart';

/// for choosing the next "Prüfkategorie" [CheckCategory] for the current [InspectionLocation]
class CategoriesView extends StatelessWidget {
  const CategoriesView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DropDownPage<CategoryModel>();
  }
}
