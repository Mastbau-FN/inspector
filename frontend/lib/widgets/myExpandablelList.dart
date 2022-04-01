import 'package:MBG_Inspektionen/classes/imageData.dart';
import 'package:MBG_Inspektionen/generated/l10n.dart';
import 'package:flutter/material.dart';

abstract class ExpandablesRadio extends StatelessWidget {
  ExpansionPanelRadio make(BuildContext context);
  @override
  Widget build(BuildContext context) {
    return ExpansionPanelList.radio(children: [make(context)]);
  }
}

class ExpandableCard2 extends ExpandablesRadio {
  final Stream<ImageData?>? previewImg;
  final Color? color;
  final String title;
  final String? subtitle;
  final Widget? extra;
  final List<Widget> children;
  final Key key;
  final double opacity;

  ExpandableCard2({
    required this.title,
    this.subtitle,
    this.extra,
    this.previewImg,
    this.children = const [],
    this.color,
    Key? key,
  })  : this.key = key ?? UniqueKey(),
        this.opacity = 1;

  ExpandableCard2._({
    required this.opacity,
    required this.title,
    this.subtitle,
    this.extra,
    this.previewImg,
    this.children = const [],
    this.color,
    Key? key,
  }) : this.key = key ?? UniqueKey();

  factory ExpandableCard2.fake() {
    return ExpandableCard2._(opacity: 0.4, title: S.current.loading);
  }

  Color _color(isExpanded, context) => !isExpanded
      ? (Theme.of(context).iconTheme.color ?? Theme.of(context).disabledColor)
      : Theme.of(context).colorScheme.secondary;

  @override
  ExpansionPanelRadio make(BuildContext context) {
    return ExpansionPanelRadio(
        backgroundColor:
            color, // Theme.of(context).colorScheme.secondary.withOpacity(0.1),
        headerBuilder: (context, isExpanded) => ListTile(
              // selectedTileColor: Theme.of(context).colorScheme.secondary,
              // selectedColor: Theme.of(context).colorScheme.secondary,
              // selected: isExpanded,
              // enabled: true,
              leading: Padding(
                padding: EdgeInsets.all(isExpanded ? 0.0 : 8.0),
                child: ClipOval(
                  child: AspectRatio(
                    aspectRatio: 1.0,
                    child: StreamBuilder<ImageData?>(
                        stream: previewImg,
                        builder: (context, snapshot) {
                          return snapshot.data?.image ??
                              Icon(
                                Icons.construction,
                                color: _color(isExpanded, context),
                              );
                        }),
                  ),
                ),
              ),
              trailing: extra,
              title: Text(
                title + (isExpanded ? ':' : ''),
                style: isExpanded
                    ? Theme.of(context).textTheme.headline5?.apply(
                          color: Theme.of(context).colorScheme.primary,
                        )
                    : Theme.of(context).textTheme.bodyText1,
              ),
              subtitle: (subtitle != null) ? Text(subtitle ?? "") : null,
            ),
        body: Container(
          // color: Theme.of(context).colorScheme.secondary,
          child: Column(
            children: [...children, SizedBox(height: 10)],
          ),
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
      children: List.generate(amount, (i) => ExpandableCard2.fake()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: ExpansionPanelList.radio(
        expansionCallback: (panelIndex, isExpanded) {
          //XXX: hier könnte ich #121 lösen vllt
        },
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
