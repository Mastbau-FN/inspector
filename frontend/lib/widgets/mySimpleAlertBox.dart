import 'package:MBG_Inspektionen/options.dart';
import 'package:flutter/material.dart';

class MySimpleAlertBox extends StatelessWidget {
  const MySimpleAlertBox({
    Key? key,
    required this.title,
    required this.bodyLines,
    required this.actions,
  }) : super(key: key);

  final String title;
  final List<String> bodyLines;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: Design.mainBorderRadius,
      ),
      title: Text(title),
      content: SingleChildScrollView(
        child: ListBody(children: bodyLines.map((e) => Text(e)).toList()),
      ),
      actions: actions,
    );
  }
}

class DismissTextButton extends StatelessWidget {
  const DismissTextButton({
    Key? key,
    this.text = 'dismiss',
  }) : super(key: key);
  final String text;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      child: Text(
        text,
        style: TextStyle(color: Theme.of(context).primaryColor),
      ),
      onPressed: () {
        Navigator.of(context).pop();
      },
    );
  }
}
