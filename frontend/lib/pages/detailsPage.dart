import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as q;

class DetailsPage extends StatefulWidget {
  final String title;
  final String? details;
  final void Function(String) onChanged;

  const DetailsPage(
      {Key? key, required this.title, this.details, required this.onChanged})
      : super(key: key);

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
            if (_isEditing) widget.onChanged("TODO: neuer String");
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

  final q.QuillController _controller = q.QuillController.basic();

  Widget get _inEdit => Column(
        children: [
          q.QuillToolbar.basic(controller: _controller),
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
