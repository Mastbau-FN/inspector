import 'package:flutter/material.dart';
import 'package:MBG_Inspektionen/widgets/error.dart';

import 'package:MBG_Inspektionen/l10n/locales.dart';

class ErrorView extends StatelessWidget {
  final Object? err;
  const ErrorView(this.err, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Scaffold(
          body: ErrorText(
              err?.toString() ?? S.of(context).anUnknownErrorOccured)),
    );
  }
}
