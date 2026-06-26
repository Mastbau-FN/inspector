import 'package:flutter/material.dart';

class ImageData<T extends Object> {
  final Image image;
  Future<Image?> fullImage() {
    final getter = fullImageGetter;
    return (getter != null) ? getter() : Future.value(image);
  }

  Future<Image?> Function()? fullImageGetter;
  final T id;
  final String? name;
  ImageData(
    this.image, {
    required this.id,
    this.name,
  });
}
