import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:MBG_Inspektionen/backend/api.dart';
import 'package:MBG_Inspektionen/classes/data/checkpointdefect.dart';
import 'package:MBG_Inspektionen/classes/data/checkpoint.dart';
import 'package:MBG_Inspektionen/classes/listTileData.dart';
import 'package:MBG_Inspektionen/fragments/adder.dart';
import 'package:MBG_Inspektionen/pages/dropdown/dropdownModel.dart';

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
            return DetailsPage(
                title: data.title,
                details: data.langText,
                onChanged: (txt) {/*TODO*/});
        }
      }),
    );
  }

  @override
  Widget? get floatingActionButton => TransformeableActionbutton(
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
            await Backend().setNew(CheckPointDefect.fromJson(defect));
            notifyListeners();
          },
          onCancel: onCancel,
          children: [
            OufnessChooser(),
            // HeightField(),
          ],
          textfield_list: [
            InputData("KurzText", hint: "Name"),
            InputData("LangText", hint: "Beschreibung"),
            InputData("Insp_Stelle", hint: "Position / Höhe"),
          ],
        ),
      );
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

class OufnessChooser extends StatefulWidget implements JsonExtractable {
  dynamic get json => _selected;
  String get name => "EREArt";

  //thats the state and its a no-no to have it in the widget itself but i need it to return the json
  int? _selected;

  State<OufnessChooser> _state = _OufnessChooserState();
  @override
  State<OufnessChooser> createState() => _state;
}

class _OufnessChooserState extends State<OufnessChooser> {
  final List<int> choices = [5201, 5202, 5203];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      children: choices
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
              widget._selected = selected ? index : null;
            });
          },
        ),
      );
}
