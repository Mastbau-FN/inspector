import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as q;

class DetailsPage extends StatefulWidget {
  final String title;
  final bool isRich;
  final String? details;
  final List<dynamic>? richDetails;
  final void Function(String)? onChanged;
  final void Function(List<dynamic>)? onRichChanged;

  const DetailsPage(
      {Key? key, required this.title, this.details, required this.onChanged})
      : this.isRich = false,
        this.onRichChanged = null,
        this.richDetails = null,
        super(key: key);

  const DetailsPage.rich(
      {Key? key,
      required this.title,
      this.richDetails,
      required void Function(List<dynamic>) onChanged})
      : this.isRich = true,
        this.onRichChanged = onChanged,
        this.onChanged = null,
        this.details = null,
        super(key: key);

  @override
  State<DetailsPage> createState() => _DetailsPageState();
}

class _DetailsPageState extends State<DetailsPage> {
  bool _isEditing = false;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            debugPrint(_controller.document.toDelta().toJson().toString());
            if (_isEditing) {
              widget.isRich
                  ? widget.onChanged!.call(_controller.document.toPlainText())
                  : widget.onRichChanged!
                      .call(_controller.document.toDelta().toJson());
            }

            _isEditing ^= true;
          });
        }, //TODO: edit text
        child: Icon(_isEditing ? Icons.done : Icons.edit),
        tooltip: "noch in arbeit..",
      ),
      body: Padding(
        padding: EdgeInsets.all(10),
        child: _body,
      ),
    );
  }

  Widget get _body => _isEditing ? _inEdit : _inShow;

  q.QuillController get _controller => q.QuillController(
        document: q.Document.fromJson(
            widget.richDetails!), //widget.isRich ? widget.details : null,
        selection: TextSelection.collapsed(offset: 0),
      );

  Widget get _inEdit => Column(
        children: [
          q.QuillToolbar.basic(locale: Locale('de'), controller: _controller),
          Expanded(
            child: Container(
              child: q.QuillEditor.basic(
                controller: _controller,
                readOnly: false, // true for view only mode
              ),
            ),
          )
        ],
      );
  Widget get _inShow => Text(widget.details ?? "");
}
