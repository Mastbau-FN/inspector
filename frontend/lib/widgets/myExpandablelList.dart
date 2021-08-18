import 'package:flutter/material.dart';

abstract class ExpandablesRadio extends StatelessWidget {
  ExpansionPanelRadio make(BuildContext context);
  @override
  Widget build(BuildContext context) {
    return ExpansionPanelList.radio(children: [make(context)]);
  }
}

class ExpandableCard2 extends ExpandablesRadio {
  final Color? color;
  final String title;
  final List<Widget> children;
  final Key key;
  ExpandableCard2(
      {required this.title, this.children = const [], this.color, Key? key})
      : this.key = key ?? UniqueKey();

  Color _color(isExpanded, context) => !isExpanded
      ? (Theme.of(context).iconTheme.color ?? Theme.of(context).disabledColor)
      : Theme.of(context).accentColor;

  @override
  ExpansionPanelRadio make(BuildContext context) {
    return ExpansionPanelRadio(
        backgroundColor: color,
        headerBuilder: (context, isExpanded) => ListTile(
              leading: Icon(
                Icons.construction,
                color: _color(isExpanded, context),
              ),
              title: Text(
                title,
                style: isExpanded
                    ? Theme.of(context).textTheme.headline5
                    : Theme.of(context).textTheme.bodyText1,
              ),
            ),
        body: Column(
          children: [...children, SizedBox(height: 10)],
        ),
        canTapOnHeader: true,
        value: key);
  }
}

class ExpandablesListRadio extends StatelessWidget {
  final List<ExpandablesRadio> children;
  const ExpandablesListRadio({this.children = const [], Key? key})
      : super(key: key);

  factory ExpandablesListRadio.fake(int amount) {
    return ExpandablesListRadio(
      children:
          List.generate(amount, (i) => ExpandableCard2(title: 'loading..')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: ExpansionPanelList.radio(
        dividerColor: Colors.transparent,
        elevation: 0,
        children: children.map((e) => e.make(context)).toList(),
      ),
    );
  }
}

/*
abstract class Expandables {
  late final bool isExpanded;
  late final ExpansionPanelHeaderBuilder build;
  ExpansionPanel get toExpansionPanel => ExpansionPanel(
        canTapOnHeader: true,
        headerBuilder: build,
        body: Container(),
      );
}

class ExpandableCard extends Expandables {
  final Widget title;

  ExpandableCard(
      {isExpanded = false, required this.title, required child, Key? key});

  @override
  ExpansionPanelHeaderBuilder build = (BuildContext context, bool isExpanded) {
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
          child: Text(isExpanded ? 'exp' : 'small') //(context),
          ),
    );
  };
}

class ExpandablesList2 extends StatefulWidget {
  final List<Expandables> children;
  const ExpandablesList2({this.children = const [], Key? key}) : super(key: key);

  @override
  _DropDownListState createState() => _DropDownListState();
}

class _DropDownListState extends State<ExpandablesList2> {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      width: 100,
      child: SingleChildScrollView(
        child: ExpansionPanelList(
          children: widget.children.map((e) => e.toExpansionPanel).toList(),
          /*[
              /*ExpansionPanel(
                  headerBuilder: (con, exp) => Text('okay,cool'),
                  body: Text('content'))*/
            ]*/
        ),
      ),
    );
  }
}*/
