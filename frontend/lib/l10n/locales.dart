import 'package:flutter/widgets.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class S {
  static AppLocalizations? current;
  static of(BuildContext context) {
    final locale = AppLocalizations.of(context)!;
    current = locale;
    return locale;
  }
}
