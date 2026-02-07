import 'package:flutter/widgets.dart';
import 'app_localizations.dart';

class S {
  static AppLocalizations? current;
  static AppLocalizations of(BuildContext context) {
    final locale = AppLocalizations.of(context)!;
    current = locale;
    return locale;
  }
}
