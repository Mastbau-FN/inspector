import 'package:MBG_Inspektionen/l10n/locales.dart';
import 'package:MBG_Inspektionen/helpers/createEditor.dart';
import 'package:flutter/material.dart';
import 'package:MBG_Inspektionen/backend/api.dart';
import 'package:MBG_Inspektionen/classes/data/checkpointdefect.dart';
import 'package:MBG_Inspektionen/classes/data/checkpoint.dart';
import 'package:MBG_Inspektionen/classes/listTileData.dart';
import 'package:MBG_Inspektionen/fragments/adder.dart';
import 'package:MBG_Inspektionen/classes/dropdownClasses.dart';

class CheckPointDefectsModel extends DropDownModel<CheckPointDefect, CheckPoint>
    implements KnowsNext<CheckPointDefect> {
  CheckPointDefectsModel(CheckPoint data) : super(data);

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

  // @override
  // get all => super.all.asyncMap((l) => l.map((e) {
  //       String t = e.title;
  //       // remove everything behind latest occurence of '#'
  //       int i = t.lastIndexOf('#');
  //       if (i != -1) {
  //         t = t.substring(0, i);
  //       }
  //       e.title = t; //would be better to do this in the element itself
  //       return e;
  //     }).toList());

  @override
  void open(
    BuildContext context,
    CheckPointDefect data,
    MyListTileData tiledata, {
    bool addImgIntend = false,
  }) {
    currentlyChosenChildData = Future.value(data);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (newcontext) {
        switch (tiledata.title) {
          case 'Fotos':
            return standard_statefulImageView(this, data,
                addImgIntent: addImgIntend);

          default:
            return Builder(builder: (context) {
              debugPrint('build new defectsdetails');
              return alwaysPlainText(this, data,
                  ((CheckPointDefect p0, p1) => update(p0, langText: p1)));
            });
        }
      }),
    );
  }

  @override
  DropDownModel<WithLangText, CheckPointDefect> generateNextModel(
      CheckPointDefect data) {
    throw UnimplementedError('thats the last one baby');
  }

  @override
  Widget? get floatingActionButton {
    return Transform.translate(
      offset: Offset(18, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          FloatingActionButton.extended(
            label: const Text('ohne Mangel'),
            onPressed: () => adder(
                withoutdefect: true,
                parent: currentData,
                onCancel: () {},
                onDone: (defect) async {
                  await API().setNew(defect, caller: currentData);
                  notifyListeners();
                }),
          ),
          PopUpActionbutton(
            expandedChild: (onCancel) => adder(
                withoutdefect: false,
                parent: currentData,
                onCancel: onCancel,
                onDone: (defect) async {
                  await API().setNew(defect, caller: currentData);
                  notifyListeners();
                }),
          ),
        ],
      ),
    );
  }

  static Adder adder({
    required bool withoutdefect,
    required CheckPoint parent,
    required onCancel(),
    required onDone(CheckPointDefect defect),
    CheckPointDefect? currentDefect,
  }) {
    var oufnessChooser = OufnessChooser(
      preSelected: currentDefect?.ereArt,
    );
    return Adder(
      'checkpointdefect',
      onSet: (json) {
        Map<String, dynamic> defect = json['checkpointdefect'];
        if (currentDefect != null) {
          defect = currentDefect.toJson()..addAll(defect);
        } else {
          debugPrint("set ${json['checkpointdefect'].toString()}");
          defect['PjNr'] = parent.pjNr;
          defect[CheckPointDefect.E1_key] = parent.category_index;
          defect[CheckPointDefect.E2_key] = parent.index;
          defect[CheckPointDefect.E3_key] = -1;
        }
        if (withoutdefect) {
          defect[CheckPointDefect.kurzText_key] =
              parent.title + "  ohne Mangel";
          defect[CheckPointDefect.ereArt_key] = OufnessChooser.default_none;
        } else {
          defect[CheckPointDefect.kurzText_key] = parent.title +
                  "  " +
                  ((defect[oufnessChooser.name].toString() ==
                          OufnessChooser.default_none.toString())
                      ? "ohne Mangel"
                      : ("Mangel " +
                          (CheckPointDefect.chipd(defect[oufnessChooser.name])
                                  ?.label ??
                              ""))) //ahhh so thats why we learn functional programming
              // +
              // "Mangel "
              //  +
              // " #" +
              // json.hashCode.toRadixString(36)
              ;
        }
        onDone(CheckPointDefect.fromJson(defect)!);
      },
      onCancel: onCancel,
      children: [
        oufnessChooser,
        //KurzTextCreator(), //creates the Mangel name //this way was utter BS i was kinda sleepy sorry lol
      ],
      textfieldList: [
        // InputData("KurzText", hint: "Name"), //removed according to #48
        InputData(
          CheckPointDefect.langText_key,
          hint: S.current!.langTextHint,
          value: currentDefect?.langText,
        ),
        InputData(CheckPointDefect.height_json_key,
            hint: S.current!.positionHeightHint,
            value: currentDefect?.height,
            verify: (val) => (val == null || val.length < 1)
                ? S.current!.heightNotOptional
                : null), //added according to #49
      ],
    );
  }
}

// ignore: must_be_immutable
class OufnessChooser extends StatefulWidget implements JsonExtractable {
  dynamic get json => _selected;
  String get name => CheckPointDefect.ereArt_key;
  int? preSelected;

  OufnessChooser({super.key, this.preSelected});

  // ignore: non_constant_identifier_names
  static final int default_none = 5204;

  final List<int> choices = [default_none, 5201, 5202, 5203];

  int get _selected => this._state.select;

  var _state = _OufnessChooserState();
  @override
  State<OufnessChooser> createState() {
    return _state = new _OufnessChooserState();
  }
}

class _OufnessChooserState extends State<OufnessChooser> {
  int select = OufnessChooser.default_none;

  @override
  void initState() {
    if (widget.preSelected != null) select = widget.preSelected!;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      children: widget.choices
          .map(
              (oufness) => choiceChip(CheckPointDefect.chipd(oufness), oufness))
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
          avatar: widget._selected == index
              ? Icon(
                  Icons.check,
                  color: Theme.of(context).colorScheme.surface,
                )
              : null,
          label: Text(
            cd?.label ?? "none",
          ),
          labelStyle: TextStyle(color: Theme.of(context).colorScheme.surface),
          selected: widget._selected == index,
          onSelected: (bool selected) {
            setState(() {
              select = selected ? index : OufnessChooser.default_none;
            });
          },
        ),
      );
}
