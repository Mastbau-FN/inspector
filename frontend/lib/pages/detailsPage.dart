import 'dart:convert';

import 'package:MBG_Inspektionen/backend/api.dart';
import 'package:flutter/material.dart';
// import 'package:flutter_quill/flutter_quill.dart' as q;

import '../classes/dropdownClasses.dart';

//das ganze widget ist iwie dumm mit dem switch zwischen String und List<Dynamic> und resultiert in ner menge "!"
class DetailsPage extends StatefulWidget {
  final String title;
  final bool isRich;
  final String? details;
  final List<dynamic>? richDetails;
  final void Function(String)? onChanged;
  final void Function(List<dynamic>)? onRichChanged;

  const DetailsPage({
    Key? key,
    required this.title,
    this.details,
    required void Function(String) onChanged,
  })  : this.isRich = false,
        this.onChanged = onChanged,
        this.onRichChanged = null,
        this.richDetails = null,
        super(key: key);

  const DetailsPage.rich(
      {Key? key,
      required this.title,
      required List<dynamic> details,
      required void Function(List<dynamic>) onChanged})
      : this.isRich = true,
        this.onRichChanged = onChanged,
        this.richDetails = details,
        this.onChanged = null,
        this.details = null,
        super(key: key);

  ///idea was to make it rich if the string is json decodeable (similar to how its currently done in [CheckPointDefects])
  // const DetailsPage.dynamic(
  //     {Key? key,
  //     required this.title,
  //     required String details,
  //     required void Function(String) onChanged})
  //     : super(key: key);

  @override
  State<DetailsPage> createState() => _DetailsPageState();
}

class _DetailsPageState extends State<DetailsPage> {
  bool _isEditing = false;
  @override
  Widget build(BuildContext context) {
    bool _isRich = widget.isRich;
    PlainEditor? _plain = _isRich
        ? null
        : PlainEditor(isEditing: _isEditing, sdetails: widget.details ?? "");
    RichEditor? _rich = _isRich
        ? RichEditor(isEditing: _isEditing, richDetails: widget.richDetails!)
        : null;
    Widget _body = _isRich ? _rich! : _plain!;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            if (_isEditing) {
              _isRich
                  ? widget.onRichChanged!.call(_rich!.details)
                  : widget.onChanged!.call(_plain!.details);
            }

            _isEditing ^= true;
          });
        },
        child: Icon(_isEditing ? Icons.done : Icons.edit),
        tooltip: "noch in arbeit..",
      ),
      body: Padding(
        padding: EdgeInsets.all(10),
        child: _body,
      ),
    );
  }
}

class PlainEditor extends StatelessWidget {
  final bool isEditing;
  final String sdetails;
  final TextInputType keyboardType;
  final List<TextInputFormatter> inputFormatters;
  PlainEditor({
    Key? key,
    this.isEditing = false,
    required this.sdetails,
    this.keyboardType = TextInputType.text,
    this.inputFormatters = const [],
  })  : this.controller = TextEditingController(text: sdetails),
        super(key: key);

  String get details => controller.text;

  @override
  Widget build(BuildContext context) => isEditing ? _inEdit : _inShow;
  Widget get _inShow => Row(
        children: [
          Text(sdetails),
          Spacer(),
        ],
      ); //// ?? "");

  Widget get _inEdit => TextFormField(
        inputFormatters: inputFormatters,
        keyboardType: keyboardType,
        minLines: 1,
        maxLines: 15,
        controller: controller,
      );

  TextEditingController controller;
}

class RichEditor extends StatelessWidget {
  final bool isEditing;
  final List<dynamic> richDetails;
  RichEditor({Key? key, this.isEditing = false, required this.richDetails})
      // // : this._controller = q.QuillController(
      // //     document: q.Document.fromJson(
      // //         richDetails), //widget.isRich ? widget.details : null,
      // //     selection: TextSelection.collapsed(offset: 0),
      // //   ),
      : super(key: key);

  List<dynamic> get details => ['depricated'];
  // // _controller.document.toDelta().toJson();

  @override
  Widget build(BuildContext context) {
    throw UnimplementedError("depricated");
  }
  // // =>
  // // Column(
  // //       children: [
  //         // if (isEditing)
  //         //   q.QuillToolbar.basic(locale: Locale('de'), controller: _controller),
  //         // Expanded(
  //         //   child: Container(
  //         //     child: q.QuillEditor.basic(
  //         //       controller: _controller,
  //         //       readOnly: !isEditing,
  //         //     ),
  //         //   ),
  //         // )
  // //       ],
  // //     );

  // // final q.QuillController _controller;
}

// Widget detailBuilder<DataT extends Data>(DataT data, Function<String> onDone) {
//   return DetailsPage.rich(
//       title: data.title,
//       details: jsonDecode('''[
//                   {
                    
//                     "insert": "bleib\\n"
//                     }
//                 ]'''),
//       onChanged: (txt) async {
//         debugPrint(jsonEncode(txt).toString());
//         data.langText = jsonEncode(txt).toString();
//         Fluttertoast.showToast(
//           msg: await Backend().update(data) ??
//               "we send the request but we didnt get any response",
//           toastLength: Toast.LENGTH_SHORT,
//           gravity: ToastGravity.CENTER,
//         );
//         onDone.call();
//       });
// }
