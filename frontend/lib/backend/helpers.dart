// MARK: general helpers:

import 'package:MBG_Inspektionen/classes/data/checkcategory.dart';
import 'package:MBG_Inspektionen/classes/data/checkpoint.dart';
import 'package:MBG_Inspektionen/classes/data/checkpointdefect.dart';
import 'package:MBG_Inspektionen/classes/data/inspection_location.dart';
import 'package:MBG_Inspektionen/classes/dropdownClasses.dart';
import 'package:flutter/material.dart';

/// since the backend api knows on which level we are by the identifier string, this function gets the identifiers for each kind of [DataT]
/// it is very import to keep these in sinc with the actual backend
String? getIdentifierFromData<DataT extends Data>(DataT? data) {
  switch (typeOf<DataT>()) {
    case CheckCategory:
      return 'category';

    case CheckPoint:
      return 'checkpoint';

    case CheckPointDefect:
      return 'defect';

    case InspectionLocation:
      return 'location';

    default:
      debugPrint("yo this type is not supported : ${typeOf<DataT>()}");
      return null;
  }
}
