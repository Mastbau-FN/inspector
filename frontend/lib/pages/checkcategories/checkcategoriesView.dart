import 'package:flutter/material.dart';
import 'package:mastbau_inspector/pages/dropdown/dropdownPage.dart';

import 'checkcategoriesModel.dart';

class CategoriesView extends StatelessWidget {
  const CategoriesView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DropDownPage<CategoryModel>();
  }
}
