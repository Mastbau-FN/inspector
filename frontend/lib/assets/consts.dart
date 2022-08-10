import 'package:flutter/material.dart';

class Options {
  static const canBeOffline = true;
  static const mergeLoadedDataIntoOnlineData =
      true; //XXX: make false to solve #212
  static const mergeLoadedDataIntoOnlineDataEvenInCachedParent = false;
  static const canUseMobileNetworkIfPossible = true;
  static const useMobileNetworkForUpload = false;
  static const useMobileNetworkForDownload = true;
  static var preferRemoteImages = false;
  static const debugAllResponses = false;
  static const debugLocalMirror = false;
  static const debugImages = false;
  static const infinitelyreloadPictures = true;
  static var reloadTries = 5;
  static var showDoggo = false;
  static const no_image_placeholder_name = "no_default_picture_yet";
}

class Design {
  static var mainBorderRadius = BorderRadius.circular(20.0);
}
