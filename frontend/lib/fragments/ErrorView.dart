import 'package:flutter/material.dart';

class ErrorView extends StatelessWidget {
  final Exception err;
  const ErrorView(this.err, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Scaffold(body: Text(err.toString())),
    );
  }
}
