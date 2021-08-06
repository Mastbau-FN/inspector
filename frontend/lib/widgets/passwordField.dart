import 'package:flutter/material.dart';

///depricated
class PasswordField_dep extends TextField {
  // mau (see https://github.com/dart-lang/sdk/issues/9468)

  @override
  bool get obscureText => true;
  @override
  bool get autocorrect => false;
  @override
  bool get enableSuggestions => false;
}
