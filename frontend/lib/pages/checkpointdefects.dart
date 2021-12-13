import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:MBG_Inspektionen/backend/api.dart';
import 'package:MBG_Inspektionen/classes/data/checkpointdefect.dart';
import 'package:MBG_Inspektionen/classes/data/checkpoint.dart';
import 'package:MBG_Inspektionen/classes/listTileData.dart';
import 'package:MBG_Inspektionen/fragments/adder.dart';
import 'package:MBG_Inspektionen/pages/dropdown/dropdownModel.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';

import 'detailsPage.dart';
import 'imageView.dart';

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
      MaterialPageRoute(builder: (newcontext) {
        switch (tiledata.title) {
          case 'Fotos':
            return ImageView.futured(
              future_images: data.image_futures,
              onNewImages: (files) => Backend().uploadFiles(data, files),
            );

          default:
            return Provider<CheckPointDefectsModel>(
              create: (context) =>
                  this, //the injector //XXX: sadly this doesnt work for some reason
              child: Builder(builder: (context) {
                debugPrint('build new defectsdetails');
                try {
                  //if langtext is already rich display in rich editor
                  return DetailsPage.rich(
                      title: data.title,
                      details: jsonDecode(data.langText ?? ""),
                      onChanged: (txt) {
                        uploadString(data, jsonEncode(txt).toString());
                      });
                } catch (e) {
                  try {
                    //if not convert it to rich if possible and display in rich editor
                    return DetailsPage.rich(
                        title: data.title,
                        details: jsonDecode(
                            '[{"insert":"${data.langText ?? ""}\\n"}]'),
                        onChanged: (txt) {
                          uploadString(data, jsonEncode(txt).toString());
                        });
                  } catch (e) {
                    return DetailsPage(
                        title: data.title,
                        details: data.langText,
                        onChanged: (txt) {
                          uploadString(data, txt);
                        });
                  }
                }
              }),
            );
        }
      }),
    );
  }

  void uploadString(CheckPointDefect data, txt) async {
    data.langText = txt;
    Fluttertoast.showToast(
      msg: await _b.update(data) ??
          "we sent the request but we didnt get any response",
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.CENTER,
    );
    notifyListeners();
  }

  @override
  Widget? get floatingActionButton {
    var oufnessChooser = OufnessChooser();
    return TransformeableActionbutton(
      expandedHeight: 300,
      expandedChild: (onCancel) => Adder(
        'checkpointdefect',
        onSet: (json) async {
          Map<String, dynamic> defect = json['checkpointdefect'];
          debugPrint("set ${json['checkpointdefect'].toString()}");
          defect['PjNr'] = currentCheckPoint.pjNr;
          defect['E1'] = currentCheckPoint.category_index;
          defect['E2'] = currentCheckPoint.index;
          defect['E3'] = -1;

          // debugPrint(defect[oufnessChooser.name].toString() +
          //     "?=" +
          //     OufnessChooser.default_none.toString() +
          //     ": " +
          //     (defect[oufnessChooser.name].toString() ==
          //             OufnessChooser.default_none.toString())
          //         .toString());

          /// this solves #48
          defect['KurzText'] = currentCheckPoint.title +
              ": " +
              ((defect[oufnessChooser.name].toString() ==
                      OufnessChooser.default_none.toString())
                  ? "ohne Mangel"
                  : ("Mangel " +
                      (CheckPointDefect.chipd(defect[oufnessChooser.name])
                              ?.label ??
                          ""))); //ahhh so thats why we learn functional programming

          await Backend().setNew(CheckPointDefect.fromJson(defect));
          notifyListeners();
        },
        onCancel: onCancel,
        children: [
          oufnessChooser,
          //KurzTextCreator(), //creates the Mangel name //this way was utter BS i was kinda sleepy sorry lol
        ],
        textfield_list: [
          // InputData("KurzText", hint: "Name"), //removed according to #48
          InputData("LangText", hint: "Beschreibung"),
          InputData("Insp_Stelle",
              hint: "Position / Höhe"), //added according to 49
        ],
      ),
    );
  }
}

// class HeightField extends StatelessWidget implements JsonExtractable {
//   dynamic get json => 3; //_height;
//   String get name => "Insp_Stelle";
//   const HeightField({Key? key}) : super(key: key);

//   // //thats the state and its a no-no to have it in the widget itself but i need it to return the json
//   // int? _height;

//   @override
//   Widget build(BuildContext context) {
//     return TextField();
//   }
// }

// class KurzTextCreator extends StatelessWidget implements JsonExtractable {
//   const KurzTextCreator({Key? key}) : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     return Container();
//   }

//   @override
//   get json => "Mangel";

//   @override
//   String get name => "KurzText";
// }

class OufnessChooser extends StatefulWidget implements JsonExtractable {
  dynamic get json => _selected;
  String get name => "EREArt";

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
