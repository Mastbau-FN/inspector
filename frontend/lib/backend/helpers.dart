// MARK: general helpers:

import 'package:MBG_Inspektionen/classes/data/checkcategory.dart';
import 'package:MBG_Inspektionen/classes/data/checkpoint.dart';
import 'package:MBG_Inspektionen/classes/data/checkpointdefect.dart';
import 'package:MBG_Inspektionen/classes/data/inspection_location.dart';
import 'package:MBG_Inspektionen/classes/dropdownClasses.dart';
import 'package:flutter/material.dart';
import 'dart:async';

enum SimulatedRequestType {
  GET,
  PUT,
  DELETE,
  POST,
}

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

extension StreamRepeatLatestExtension<T /*extends Object*/ > on Stream<T> {
  Stream<T> repeatLatest() {
    var done = false;
    T? latest;
    var currentListeners = <MultiStreamController<T>>{};
    this.listen((event) {
      latest = event;
      for (var listener in [...currentListeners]) listener.addSync(event);
    }, onError: (Object error, StackTrace stack) {
      for (var listener in [...currentListeners])
        listener.addErrorSync(error, stack);
    }, onDone: () {
      //TODO: PERFORMANCE, okay we currently dont close the streams so photos can be shown again (see #36), but thats very bad for performance, so find an actual solution instead of a dirty workaround
      // done = true;
      // latest = null;
      // for (var listener in currentListeners) listener.close();
      // currentListeners.clear();
    });
    return Stream.multi((controller) {
      if (done) {
        controller.close();
        return;
      }
      currentListeners.add(controller);
      var latestValue = latest;
      if (latestValue != null) controller.add(latestValue);
      controller.onCancel = () {
        currentListeners.remove(controller);
      };
    });
  }
}
