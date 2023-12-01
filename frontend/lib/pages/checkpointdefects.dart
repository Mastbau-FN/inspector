import 'package:MBG_Inspektionen/l10n/locales.dart';
import 'package:MBG_Inspektionen/helpers/createEditor.dart';
import 'package:MBG_Inspektionen/pages/dropDownPageB.dart';
import 'package:MBG_Inspektionen/widgets/trashbutton.dart';
import 'package:flutter/material.dart';
import 'package:MBG_Inspektionen/backend/api.dart';
import 'package:MBG_Inspektionen/classes/data/checkpointdefect.dart';
import 'package:MBG_Inspektionen/classes/data/checkpoint.dart';
import 'package:MBG_Inspektionen/classes/listTileData.dart';
import 'package:MBG_Inspektionen/fragments/adder.dart';
import 'package:MBG_Inspektionen/classes/dropdownClasses.dart';
import 'package:provider/provider.dart';

import '../widgets/mySimpleAlertBox.dart';

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
  Widget? floatingActionButton(BuildContext context) {
    return PopUpActionbutton(
      expandedChild: (onCancel) => adder(
          // withoutdefect: false,
          parent: currentData,
          onCancel: onCancel,
          onDone: (defect) async {
            await API().setNew(defect, caller: currentData);
            notifyListeners();
          }),
    );
  }

  ohneMaengelAction(context) async {
    if ((await all().last).isEmpty) {
      // final x = currentData;
      await API().setNew<CheckPointDefect>(
        CheckPointDefect(
          pjNr: currentData.pjNr,
          category_index: currentData.category_index,
          check_index: currentData.index,
          index: -1,
          ereArt: OufnessChooser.none,
          kurzText: currentData.title + "  ohne Mangel",
          langText: "ohne Mangel",
        )..id = "0", //TODO: test
        // ..height = "----",
        caller: currentData,
      ); //TO-DO: does not work in online mode #387
      notifyListeners();
      return;
    } else {
      showDialog(
        barrierColor: Colors.black54,
        context: context,
        builder: (BuildContext context) {
          return MySimpleAlertBox(
            actions: <Widget>[
              Center(
                child: TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: Text(S.current!.cancel)),
              ),
            ],
            title: S.of(context).uhoh,
            bodyLines: [
              S.of(context).areYouSure,
            ],
          );
        },
      );
    }
  }

  Widget ohneMaengelButton(BuildContext context) {
    return FutureBuilder(
        future: all().last,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return Container();
          }
          return TextButton(
              style: TextButton.styleFrom(
                foregroundColor:
                    Theme.of(context).colorScheme.onPrimaryContainer,
                // iconColor: Theme.of(context)
                //     .colorScheme
                //     .onPrimaryContainer,
                backgroundColor: snapshot.data!.isNotEmpty
                    ? Colors.grey.shade400
                    : Theme.of(context).colorScheme.primaryContainer,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                padding: EdgeInsets.all(0),
              ),
              onPressed: () => ohneMaengelAction(context),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    Icon(
                      Icons.check,
                    ),
                    SizedBox(width: 5),
                    Text(S.of(context).ohneMaengel),
                  ],
                ),
              ));
        });
  }

  static Adder adder({
    // required bool withoutdefect,
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
        // if (withoutdefect) {
        //   defect[CheckPointDefect.kurzText_key] =
        //       parent.title + "  ohne Mangel";
        //   defect[CheckPointDefect.ereArt_key] = OufnessChooser.none;
        // } else {
        defect[CheckPointDefect.kurzText_key] =
                //parent.title +
                //"  " +
                ((defect[oufnessChooser.name].toString() ==
                        OufnessChooser.none.toString())
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
        // }
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
  static final int none = 5204;
  static final int default_val = 5201;

  final List<int> choices = [5201, 5202, 5203];

  int get _selected => this._state.select;

  var _state = _OufnessChooserState();
  @override
  State<OufnessChooser> createState() {
    return _state = new _OufnessChooserState();
  }
}

class _OufnessChooserState extends State<OufnessChooser> {
  int select = OufnessChooser.default_val;

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
          // avatar: widget._selected == index
          //     ? Icon(
          //         Icons.check,
          //         color: Theme.of(context).colorScheme.surface,
          //       )
          //     : null,
          label: Text(
            cd?.label ?? "none",
          ),
          labelStyle: TextStyle(color: Theme.of(context).colorScheme.surface),
          selected: widget._selected == index,
          onSelected: (bool selected) {
            setState(() {
              select = index; //selected ? index : OufnessChooser.default_val;
            });
          },
        ),
      );
}

Widget generateCheckPointDefectsSliverList(
    BuildContext context, List<CheckPointDefect> childrenData) {
  return SliverList.list(
    children: childrenData.map((cd) {
      return DefectWidgetAuto(data: cd);
    }).toList(),
  );
}

class DefectWidgetAuto extends StatefulWidget {
  final CheckPointDefect data;
  const DefectWidgetAuto({super.key, required this.data});

  @override
  State<DefectWidgetAuto> createState() => _DefectWidgetStateAuto();
}

class _DefectWidgetStateAuto extends State<DefectWidgetAuto> {
  bool isExpanded = false;
  @override
  Widget build(BuildContext context) {
    return DefectWidget(
      onExpansionChanged: (newVal) => setState(() {
        isExpanded = newVal;
      }),
      isExpanded: isExpanded,
      data: widget.data,
    );
  }
}

// - Das bisherige Aufklappen der Mängel wird geändert: Unterpunkte "Details" und "Fotos" werden nicht mehr benötigt.
// - Obere Textzeile enthält in Zukunft den Text von "Höhe/Position/Ort" => "Ort: xxxxxx"
// - Die 2. Textzeile enthält die "Beschreibung"   => "Info: xxxxxx"
// - Die bisherige 1. Textzeile entfällt.

// - Texte werden maximal 2-zeilig dargestellt.
// - Durch Klicken auf Mangel-Typ oder einer der Texte vergrößern sich die Textboxen und der gesamte Text wird dargestellt. Maximal so, dass ein Folge- Mangel noch im sichtbaren Bereich ist. ( Oder Maximal 10 Zeilen.)

// - ist Text länger als maximal darstellbar,kann durch Wischen der Rest hergescrollt werden.

// - Die alte 1. Textzeile wird nicht mehr visuell benötigt. Diese wird nirgends mehr in GUI dargestellt. Im Hintergrund soll es aber diesen Text noch geben. Dabei ist die Nennung von "Prüfpunkt" nicht mehr wichtig und auch nicht mehr möglich . Hier verbleibt also nur noch der Text  Z.B. "Mangel leicht"

// -  Durch Klicken auf das Foto-Icon wird der Foto-Ordner-Dialog aufgerufen
// -  Für ältere Herren gibt es zum Öffnen des Foto-Ordners ein extra "Ordner"-Icon neben "KameraPlus"-Icon und "Stift"-Icon. Galerie-Icon

class DefectWidget extends StatelessWidget {
  final CheckPointDefect data;
  final bool isExpanded;
  final void Function(bool) onExpansionChanged;

  const DefectWidget(
      {super.key,
      required this.onExpansionChanged,
      this.isExpanded = false,
      required this.data});

  static const _maxLines = 2;
  static const _maxLinesExpanded = 10;
  static const _padding = 10.0;
  static const _iconSize = 15.0;

  @override
  Widget build(BuildContext context) {
    // [1, 2, 3].indexed.any((element) => element.$1 == 2);
    return Padding(
      padding: const EdgeInsets.fromLTRB(_padding, _padding, _padding, 0),
      child: TextButton(
        style: TextButton.styleFrom(
          // iconColor: Theme.of(context).colorScheme.onSurface,
          foregroundColor:
              CheckPointDefect.ereArtToColor(data.ereArt).withOpacity(1),
          // primary: Theme.of(context).colorScheme.onSurface,
          backgroundColor: Theme.of(context).colorScheme.surface,
          elevation: 10,
          //     CheckPointDefect.ereArtToColor(data.ereArt).withOpacity(0.4),
          shadowColor:
              CheckPointDefect.ereArtToColor(data.ereArt).withOpacity(0.8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          // side: BorderSide(
          //   color: CheckPointDefect.ereArtToColor(data.ereArt),
          //   width: 1,
          // ),
          padding: EdgeInsets.all(0),
        ).copyWith(
          foregroundColor:
              MaterialStatePropertyAll(Theme.of(context).colorScheme.onSurface),
        ),
        onPressed: () => onExpansionChanged(!isExpanded),
        child: IntrinsicHeight(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(15),
                    bottomLeft: Radius.circular(15),
                  ),
                  color: CheckPointDefect.ereArtToColor(data.ereArt)
                      .withOpacity(1),
                ),
                width: 40,
                child: Center(
                    child: RotatedBox(
                        quarterTurns: 3,
                        child: Text(
                          CheckPointDefect.ereArtToString(data.ereArt),
                          style: TextStyle(color: Colors.white),
                        ))),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SizedBox(
                        child: TextButton(
                          style: (Theme.of(context).textButtonTheme.style ??
                                  ButtonStyle())
                              .copyWith(
                            padding: MaterialStateProperty.all(EdgeInsets.zero),
                            iconColor: MaterialStateProperty.all(
                                Theme.of(context).colorScheme.onSurface),
                          ),
                          onPressed: () {
                            var model = Provider.of<CheckPointDefectsModel>(
                                context,
                                listen: false);
                            model.open(
                                context, data, MyListTileData(title: 'Fotos'),
                                addImgIntend: false);
                          },
                          child: PreviewImageCircle(
                            previewImage: data.previewImage,
                            fallbackIcon: Icons.photo_library,
                          ),
                        ),
                        height: 50,
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                            0, _padding, _padding, _padding),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.location_on, size: _iconSize),
                                SizedBox(width: 5),
                                Text(S.of(context).defectLocation(
                                    data.height ?? S.of(context).unknown)),
                              ],
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.info, size: _iconSize),
                                SizedBox(width: 5),
                                SizedBox(
                                  width: MediaQuery.of(context).size.width -
                                      50 - //image width
                                      _padding * 2 - //inner padding
                                      _padding * 2 - //outer padding
                                      5 - //icon spacer
                                      // 8 - // card padding
                                      4 - // textButoon stuff idk
                                      40 - //right banner
                                      _iconSize //icon size
                                  ,
                                  child: Text(
                                    S
                                        .of(context)
                                        .defectInfo(data.langText ?? ""),
                                    maxLines: isExpanded
                                        ? _maxLinesExpanded
                                        : _maxLines,
                                    softWrap: true,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(
                    height: 50,
                    width: MediaQuery.of(context).size.width -
                        // _padding * 2 - //inner padding
                        _padding * 2 - //outer padding
                        // 8 - // card padding
                        4 - // textButoon stuff idk
                        40 //right banner
                    ,
                    child: Row(
                      children: [
                        Spacer(),
                        ...data
                            .extras(context: context)
                            .indexed
                            .map<Widget>((a) {
                          final (int i, Widget action) = a;
                          if (i == 0) return SizedBox();
                          return action;
                        }).toList(),
                        TrashButton(delete: () async {
                          final model = Provider.of<CheckPointDefectsModel>(
                              context,
                              listen: false);

                          await API().delete<CheckPointDefect>(data,
                              caller: model.currentData);
                          model.notifyListeners();
                        }),
                      ],
                    ),
                  )
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
