import 'package:flutter/material.dart';

class DropDownList extends StatefulWidget {
  final List<ExpansionPanel> children;
  const DropDownList({this.children = const [], Key? key}) : super(key: key);

  @override
  _DropDownListState createState() => _DropDownListState();
}

class _DropDownListState extends State<DropDownList> {
  @override
  Widget build(BuildContext context) {
    return Container(
      child: ExpansionPanelList(
        children: widget.children,
      ),
    );
  }
}
