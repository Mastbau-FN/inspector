import 'package:flutter/services.dart';

void initialize(token) =>
    BackgroundIsolateBinaryMessenger.ensureInitialized(token);
