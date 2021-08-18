import 'package:flutter/material.dart';

class MainDropDown extends ExpansionPanel {
  final bool isExpanded;
  final Widget title;
  final Widget child;
  final ExpansionPanelHeaderBuilder header = (context, isExpanded) {
    return Text('breh');
  };
  MainDropDown(
      {this.isExpanded = false,
      required this.title,
      required this.child,
      Key? key})
      : super(body: Text('never'), headerBuilder: (c, b) => Text('never'));
  /*: super(
            body: Text('irrelevant'),
            headerBuilder: header);*/

  @override
  Widget get body => Text("lol");

  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20.0),
      ),
      elevation: 8.0,
      margin: EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
      child: AnimatedContainer(
          duration: Duration(milliseconds: 200),
          color: isExpanded ? Colors.primaries[0] : Colors.primaries[1],
          height: 100,
          width: 100,
          child: super.body //(context),
          ),
    );
  }
}
