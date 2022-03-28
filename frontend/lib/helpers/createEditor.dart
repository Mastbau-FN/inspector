import 'dart:convert';

import 'package:MBG_Inspektionen/classes/dropdownClasses.dart';
import 'package:MBG_Inspektionen/pages/detailsPage.dart';

DetailsPage createRichIfPossibleEditor<DataT extends WithLangText>(
    DataT data, Function(DataT, String) uploadString) {
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
          details: jsonDecode('[{"insert":"${data.langText ?? ""}\\n"}]'),
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
}

DetailsPage alwaysPlainText<DataT extends WithLangText>(
    DataT data, Function(DataT, String) uploadString) {
  return DetailsPage(
      title: data.title,
      details: data.langText,
      onChanged: (txt) {
        uploadString(data, txt);
      });
}
