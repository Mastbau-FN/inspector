import 'package:MBG_Inspektionen/classes/dropdownClasses.dart';
import 'package:MBG_Inspektionen/helpers/toast.dart';
import 'package:MBG_Inspektionen/pages/detailsPage.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../generated/l10n.dart';

// rich was totally removed
// DetailsPage createRichIfPossibleEditor<DataT extends WithLangText>(
//     DataT data, Function(DataT, String) uploadString) {
//   try {
//     //if langtext is already rich display in rich editor
//     return DetailsPage.rich(
//         title: data.title,
//         details: jsonDecode(data.langText ?? ""),
//         onChanged: (txt) {
//           uploadString(data, jsonEncode(txt).toString());
//         });
//   } catch (e) {
//     try {
//       //if not convert it to rich if possible and display in rich editor
//       return DetailsPage.rich(
//           title: data.title,
//           details: jsonDecode('[{"insert":"${data.langText ?? ""}\\n"}]'),
//           onChanged: (txt) {
//             uploadString(data, jsonEncode(txt).toString());
//           });
//     } catch (e) {
//       return DetailsPage(
//           title: data.title,
//           details: data.langText,
//           onChanged: (txt) {
//             uploadString(data, txt);
//           });
//     }
//   }
// }

Widget alwaysPlainText<ChildData extends WithLangText,
            DDModel extends DropDownModel<ChildData, WithOffline?>>(
        DDModel model,
        ChildData data,
        Function(ChildData, String) uploadString) =>
    ChangeNotifierProvider<DDModel>.value(
        value: model,
        // child: ChangeNotifierProvider<ChildData>.value(
        //   value: data,
        child: Builder(builder: (context) {
          return Consumer<DDModel>(builder: (context, model, child) {
            // return Consumer<ChildData>(builder: (context, data, child) {
            return FutureBuilder<ChildData?>(
                future: model.currentlyChosenChildData,
                builder: (context, snapshot) {
                  return DetailsPage(
                      title: (snapshot.data ?? data).title,
                      details: (snapshot.data ?? data).langText,
                      onChanged: (txt) {
                        showToast(S.of(context).uploading);
                        model.updateCurrentChild((p0) => uploadString(p0, txt));
                      });
                });
          });
        }));
