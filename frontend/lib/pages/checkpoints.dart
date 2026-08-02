import 'package:MBG_Inspektionen/classes/data/checkpointdefect.dart';
import 'package:MBG_Inspektionen/backend/categoryProgressState.dart';
import 'package:MBG_Inspektionen/l10n/locales.dart';
import 'package:MBG_Inspektionen/helpers/createEditor.dart';
import 'package:MBG_Inspektionen/helpers/inspection_text.dart';
import 'package:MBG_Inspektionen/options.dart';
import 'package:flutter/material.dart';
import 'package:MBG_Inspektionen/backend/api.dart';
import 'package:MBG_Inspektionen/classes/data/checkcategory.dart';
import 'package:MBG_Inspektionen/classes/data/checkpoint.dart';
import 'package:MBG_Inspektionen/classes/listTileData.dart';
import 'package:MBG_Inspektionen/fragments/adder.dart';
import 'package:MBG_Inspektionen/pages/checkpointdefects.dart';
import 'package:MBG_Inspektionen/classes/dropdownClasses.dart';

const predefinedCategories1 = [
  "Kennzeichnung Zuwegung",
  "Ausführung",
  "sonstiges"
];
const predefinedCategories2 = [
  "Steckerbrücke",
  "Potentialausgleich",
  "Kabelweg",
  "Kabeleinführung",
  "Brandschutz",
  "sonstiges"
];
const predefinedCategories3 = [
  "Typ",
  "Verbinder",
  "Auflager Stütze Halterung",
  "Kantenschutz",
  "Korrosion",
  "Vandalismusschutz",
  "Deckel Eisschutz",
  "Erdung",
  "sonstiges"
];
const predefinedCategories4 = [
  "Tragkonstruktion",
  "Gitterroste",
  "Gitterrostklemmen",
  "Verbindungsmittel",
  "Geländer",
  "Klappen",
  "Fußleisten Trittschutzeinrichtungen",
  "sonstiges"
];
const predefinedCategories5 = [
  "Art Typ",
  "Zustand",
  "Kennzeichnung",
  "Eindichtung",
  "Verbindungsmittel",
  "sonstiges"
];
const predefinedCategories6 = [
  "Allgemeiner Zustand",
  "Bewuchs",
  "Beschichtung",
  "Risse Abplatzungen",
  "Wasserablauf",
  "sonstiges"
];
const predefinedCategories7 = [
  "Anschlüsse",
  "Auffangeinrichtung",
  "Ableitung",
  "Erdung",
  "Potentialausgleich",
  "Isolierter Aufbau",
  "HVI",
  "sonstiges"
];
const predefinedCategories8 = [
  "Überspannungsableiter",
  "Tragwerk",
  "Verbindungsmittel",
  "Konstruktion",
  "Beschichtung",
  "Stoßverbindungen",
  "Schweißnähte",
  "Wassserabläufe, Zinklöcher o.ä.",
  "Eindichtungen",
  "sonstiges"
];
const predefinedCategories9 = [
  "Verbindungsmittel",
  "Halterung",
  "Korrosion",
  "Antenne",
  "Verteiler",
  "Wassserabläufe, Zinklöcher o.ä.",
  "sonstiges"
];
const predefinedCategories10 = [
  "Verbindungsmittel",
  "Hersteller Typ",
  "Endsperre",
  "Steigsperre",
  "Aussparung",
  "Kennzeichnungsschild",
  "Spaltmaße",
  "Leiterhalterungen",
  "Drehkreuz",
  "Besteigschutz",
  "Biegung",
  "Ausstiegsvorrichtung",
  "Ruhepodeste",
  "Steigschutzschlüssel",
  "Antritt",
  "Tritttiefen Hindernisse",
  "Mobile Steigleitern",
  "sonstiges"
];
const predefinedCategories11 = [
  "Verbindungsmittel",
  "Kabel",
  "Erdung",
  "Kabelschellen",
  "Kabelbahn",
  "Kabeleinführung",
  "Jumper",
  "Stecker",
  "sonstiges"
];
const predefinedCategories12 = [
  "Beschichtung",
  "Vorspannung",
  "Seilschuhe",
  "Spanneinrichtungen",
  "sonstiges"
];
const predefinedCategories13 = ["Leuchten", "Kabel", "Halterung", "sonstiges"];
const predefinedCategories14 = [
  "Typ",
  "Zustand",
  "Sicherung, Siegel, Plombe",
  "Kennzeichnung",
  "Befestigung",
  "sonstiges"
];
const predefinedCategories15 = [
  "Tresor",
];
final Map<String, List<String>> predefinedCategoryMap = {
  "Weg zum Mast": predefinedCategories1,
  "Funkraum Container": predefinedCategories2,
  "Kabelrinne": predefinedCategories3,
  "Bühnen": predefinedCategories4,
  "Anschlagpunkte": predefinedCategories5,
  "Fundamente": predefinedCategories6,
  "Blitzschutz Erdung": predefinedCategories7,
  "Tragwerk": predefinedCategories8,
  "Antennen & Antennenhalterungen": predefinedCategories9,
  "Steigweg": predefinedCategories10,
  "Kabel & Kabelweg": predefinedCategories11,
  "Abspannungen Pardunen": predefinedCategories12,
  "Flugfeuer": predefinedCategories13,
  "Rettungsgerät": predefinedCategories14,
  "Standortschließung Tresor": predefinedCategories15,
};
List<String> getPredefinedCategory(String key) {
  final directMatch = predefinedCategoryMap[key];
  if (directMatch != null) return directMatch;

  final normalizedKey = normalizeInspectionLabel(key);
  if (normalizedKey.isEmpty) return const [];
  for (final entry in predefinedCategoryMap.entries) {
    if (normalizeInspectionLabel(entry.key) == normalizedKey) {
      return entry.value;
    }
  }
  return const [];
}

class CheckPointsModel extends DropDownModel<CheckPoint, CheckCategory>
    implements KnowsNext<CheckPoint> {
  CheckPointsModel(CheckCategory p) : super(p);

  static const _nextViewTitle = "Mängel";

  @override
  List<MyListTileData> actions = [
    MyListTileData(
      title: _nextViewTitle,
      icon: Icons.report_problem,
    ),
    if (!omitDetailsInLevel2and3)
      MyListTileData(
        title: "Fotos",
        icon: Icons.photo_library,
      ),
    if (!omitDetailsInLevel2and3)
      MyListTileData(
        title: "Kommentar",
        icon: Icons.text_snippet,
      ),
  ];

  @override
  CheckPointDefectsModel generateNextModel(CheckPoint data) {
    data.parentId = currentData.id;
    return CheckPointDefectsModel(data);
  }

  @override
  void open(
    BuildContext context,
    CheckPoint data,
    MyListTileData tiledata,
  ) {
    currentlyChosenChildData = Future.value(data);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (newcontext) {
        switch (tiledata.title) {
          case _nextViewTitle:
            return nextModel<CheckPointDefect, CheckPoint,
                CheckPointDefectsModel>(generateNextModel(data));
          case 'Fotos':
            return standard_statefulImageView(this, data);

          default:
            return alwaysPlainText(
                this, data, ((CheckPoint p0, p1) => update(p0, langText: p1)));
        }
      }),
    );
  }

  @override
  Widget? floatingActionButton(BuildContext context) {
    return PopUpActionbutton(
      expandedChild: (onCancel) => adder(
        parent: currentData,
        onCancel: onCancel,
        onDone: (category) async {
          final createdCheckpoint =
              await API().setNew(category, caller: currentData);
          if (createdCheckpoint != null) {
            CategoryProgressState.instance.checkpointAdded(
              categoryId: currentData.id,
            );
          }
          notifyListeners();
        },
      ),
    );
  }

  static Adder adder({
    required CheckCategory parent,
    required onCancel(),
    required onDone(CheckPoint checkpoint),
    CheckPoint? currentCheckpoint,
  }) {
    return Adder(
      'checkpoint',
      onSet: (json) {
        Map<String, dynamic> checkpoint = json['checkpoint'];

        if (currentCheckpoint != null) {
          checkpoint = currentCheckpoint.toJson()..addAll(checkpoint);
        } else {
          checkpoint['PjNr'] = parent.pjNr;
          checkpoint['E1'] = parent.index;
          checkpoint['E2'] = -1;
        }
        onDone(CheckPoint.fromJson(checkpoint)!);
      },
      onCancel: onCancel,
      textfieldList: [
        InputData(
          "KurzText",
          hint: S.current!.kurzTextHint,
          value: currentCheckpoint?.kurzText,
          dropdown: getPredefinedCategory(parent.kurzText!),
          postProcess: InputData.noSpacesAtEnd,
        ),
        InputData(
          "LangText",
          hint: S.current!.langTextHint,
          verify: InputData.alwaysCorrect,
          value: currentCheckpoint?.langText,
        ),
      ],
    );
  }
}
