import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:mastbau_inspector/backend/api.dart';
import 'package:mastbau_inspector/classes/data/checkpointdefect.dart';
import 'package:mastbau_inspector/classes/data/checkpoint.dart';
import 'package:mastbau_inspector/classes/listTileData.dart';
import 'package:mastbau_inspector/fragments/adder.dart';
import 'package:mastbau_inspector/pages/dropdown/dropdownModel.dart';

class CheckPointDefectsModel extends DropDownModel<CheckPointDefect> {
  final Backend _b = Backend();
  final CheckPoint currentCheckPoint;

  CheckPointDefectsModel(this.currentCheckPoint);

  Future<List<CheckPointDefect>> get all async =>
      _b.getAllDefectsForCheckpoint(currentCheckPoint);

  @override
  List<MyListTileData> actions = [
    MyListTileData(
      title: "Details",
      icon: Icons.info,
    ),
    MyListTileData(
      title: "Fotos",
      icon: Icons.photo_library,
    ),
  ];

  @override
  String get title => currentCheckPoint.title;

  @override
  void open(
    BuildContext context,
    CheckPointDefect data,
    MyListTileData tiledata,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (newcontext) => Text("TODO"),
      ),
    );
  }

  @override
  Widget? get floatingActionButton => TransformeableActionbutton(
        expandedChild: (onCancel) => Adder(
          'checkpointdefects',
          onCancel: onCancel,
          children: [
            OufnessChooser(),
          ],
          textfield_list: [
            InputData("KurzText", hint: "Name"),
            InputData("LangText", hint: "Beschreibung"),
          ],
        ),
      );
}

class OufnessChooser extends StatefulWidget implements JsonExtractable {
  Map<String, dynamic> get json => {};
  String get name => "oufness";

  @override
  State<OufnessChooser> createState() => _OufnessChooserState();
}

class _OufnessChooserState extends State<OufnessChooser> {
  int? _selected;
  final List<int> choices = [1, 2, 3];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      children: choices
          .map((oufness) =>
              choiceChip(CheckPointDefect.chipd(oufness + 5200), oufness))
          .toList(),
    );
  }

  Widget choiceChip(ChipData? cd, int index) => Padding(
        padding: const EdgeInsets.all(8.0),
        child: ChoiceChip(
          elevation: 4,
          shadowColor:
              Theme.of(context).colorScheme.onBackground.withAlpha(100),
          selectedShadowColor: cd?.backgroundColor,
          selectedColor: cd?.backgroundColor,
          backgroundColor: cd?.backgroundColor?.withAlpha(70),
          avatar: _selected == index
              ? Icon(
                  Icons.check,
                  color: Theme.of(context).colorScheme.surface,
                )
              : null,
          label: Text(
            cd?.label ?? "none",
          ),
          labelStyle: TextStyle(color: Theme.of(context).colorScheme.surface),
          selected: _selected == index,
          onSelected: (bool selected) {
            setState(() {
              _selected = selected ? index : null;
            });
          },
        ),
      );
}
