import 'package:flutter/material.dart';

class ImageData<T extends Object> {
  final Image thumbnail;
  Future<Image?> fullImage() =>
      fullImageGetter?.call() ?? Future.value(thumbnail);
  Future<Image?> Function()? fullImageGetter;
  final T id;
  ImageData(
    this.thumbnail, {
    this.fullImageGetter,
    required this.id,
  });
}
