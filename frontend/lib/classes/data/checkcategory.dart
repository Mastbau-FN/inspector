import 'package:mastbau_inspector/pages/dropdown/dropdownModel.dart';
import 'package:json_annotation/json_annotation.dart';

part 'checkcategory.g.dart';

@JsonSerializable()
class CheckCategory implements Data {
  @JsonKey(name: 'PjNr')
  int pjNr;
  @JsonKey(name: 'Bauleitung')
  String? bauleitung;
  @JsonKey(name: 'KurzText')
  String? kurzText;
  @JsonKey(name: 'LangText')
  String? langText;
  ////Null link;
  ////Null linkOrdner;
  @JsonKey(name: 'ErDat')
  DateTime? erDate;
  @JsonKey(name: 'EventID')
  int? eventID;
  @JsonKey(name: 'EREArt')
  int? ereArt;
  @JsonKey(name: 'E1')
  int index;
  @JsonKey(name: 'E2')
  int? e2;
  @JsonKey(name: 'E3')
  int? e3;

  CheckCategory(
      {required this.pjNr,
      this.bauleitung,
      this.kurzText,
      this.langText,
      ////this.link,
      ////this.linkOrdner,
      this.erDate,
      this.eventID,
      this.ereArt,
      required this.index,
      this.e2,
      this.e3});

  @override
  String get title => kurzText ?? langText ?? '$pjNr: Kategorie $index';

  static CheckCategory? fromJson(Map<String, dynamic> json) {
    try {
      return _$CheckCategoryFromJson(json);
    } catch (e) {}
  }

  @override
  Map<String, dynamic> toJson() => _$CheckCategoryToJson(this);

  @override
  Map<String, dynamic> toSmallJson() => {'PjNr': pjNr, 'E1': index};
}
