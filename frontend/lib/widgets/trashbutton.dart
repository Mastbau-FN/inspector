import 'package:MBG_Inspektionen/fragments/loadingscreen/loadingView.dart';
import 'package:flutter/material.dart';

import 'mySimpleAlertBox.dart';

class TrashButton extends StatefulWidget {
  const TrashButton(
      {Key? key, required this.delete, this.confirmation_needed = true})
      : super(key: key);

  final Future Function() delete;
  final bool confirmation_needed;

  @override
  State<TrashButton> createState() => _TrashButtonState();
}

class _TrashButtonState extends State<TrashButton> {
  bool undeleted = true;

  Future<void> _confirmed_delete(BuildContext context) async {
    return showDialog<void>(
      context: context,
      //barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return MySimpleAlertBox(
          actions: <Widget>[
            DismissTextButton(),
            TextButton(onPressed: _delete, child: Text('ja, sicher, Löschen!'))
          ],
          title: 'Sicher?',
          bodyLines: [
            'wirklich Löschen?',
            'diese Aktion ist entgültig und nicht wiederherstellbar'
          ],
        );
      },
    );
  }

  void _delete() {
    setState(() {
      undeleted = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (undeleted)
      return IconButton(
        onPressed: () {
          if (widget.confirmation_needed)
            _confirmed_delete(context);
          else
            _delete();
        },
        icon: Icon(Icons.delete),
      );
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: FutureBuilder(
          future: widget.delete(),
          builder: (BuildContext context, AsyncSnapshot snapshot) {
            switch (snapshot.connectionState) {
              case ConnectionState.waiting:
              case ConnectionState.active:
                return LoadingView();
              default:
                return Icon(Icons.check);
            }
          }),
    );
  }
}
