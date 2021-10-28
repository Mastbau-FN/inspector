import 'package:flutter/material.dart';

class DetailsPage extends StatelessWidget {
  final String title;
  final String? details;
  final void Function(String) onChanged;

  const DetailsPage(
      {Key? key, required this.title, this.details, required this.onChanged})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {}, //TODO: edit text
        child: Icon(Icons.edit),
        tooltip: "noch in arbeit..",
      ),
      body: Padding(
        padding: EdgeInsets.all(10),
        child: Text(details ?? ""),
      ),
    );
  }
}
