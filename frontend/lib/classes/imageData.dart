import 'package:flutter/material.dart';

class ImageData<T extends Object> {
  Image image;
  T id;
  ImageData(this.image, {required this.id});
}
