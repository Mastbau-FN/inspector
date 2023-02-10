import 'package:MBG_Inspektionen/widgets/rotating.dart';
import 'package:flutter/material.dart';

import '../../generated/l10n.dart';

class LoadingView extends StatelessWidget {
  const LoadingView({Key? key, this.fixedSize = true}) : super(key: key);
  final bool fixedSize;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        height: fixedSize ? 20 : null,
        width: fixedSize ? 20 : null,
        child: AspectRatio(
          aspectRatio: 1,
          child: Rotating(
            child: AspectRatio(
              aspectRatio: 1,
              child: Image(
                image: AssetImage('lib/assets/icon.png'),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class LoadingPage extends StatelessWidget {
  const LoadingPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.loading),
      ),
      body: Padding(
        padding: const EdgeInsets.all(80.0),
        child: LoadingView(),
      ),
    );
  }
}
