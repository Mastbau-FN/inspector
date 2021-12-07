import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as q;

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
                  ? widget.onChanged!.call(_basicController.text)
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
  Widget get _inShow => widget.isRich ? _richShow : _plainShow;
  Widget get _inEdit => widget.isRich ? _richEdit : _plainEdit;

  Widget get _plainShow {
    return Text(widget.details ?? "");
  }

  Widget get _plainEdit => TextFormField(
        initialValue: widget.details ?? "",
        controller: _basicController,
      );

  Widget get _richEdit => _rich(inEdit: true);
  Widget get _richShow => _rich(inEdit: false);

  Widget _rich({required bool inEdit}) => Column(
        children: [
          q.QuillToolbar.basic(locale: Locale('de'), controller: _controller),
          Expanded(
            child: Container(
              child: q.QuillEditor.basic(
                controller: _controller,
                readOnly: !inEdit,
              ),
            ),
          )
        ],
      );

  TextEditingController get _basicController => TextEditingController();
  q.QuillController get _controller => q.QuillController(
        document: q.Document.fromJson(
            widget.richDetails!), //widget.isRich ? widget.details : null,
        selection: TextSelection.collapsed(offset: 0),
      );
}
