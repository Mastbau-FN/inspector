import 'package:flutter/material.dart';
import 'package:mastbau_inspector/widgets/error.dart';

class ErrorView extends StatelessWidget {
  final Object? err;
  const ErrorView(this.err, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Scaffold(body: ErrorText(err?.toString() ?? 'an error occured')),
    );
  }
}
