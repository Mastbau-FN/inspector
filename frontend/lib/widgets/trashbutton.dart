import 'package:MBG_Inspektionen/widgets/rotating.dart';
import 'package:flutter/material.dart';

import '../generated/l10n.dart';
import 'mySimpleAlertBox.dart';

class TrashButton extends StatefulWidget {
  const TrashButton({
    Key? key,
    required this.delete,
    this.confirmationNeeded = true,
    this.confirmName,
  }) : super(key: key);

  final Future Function() delete;
  final bool confirmationNeeded;
  final String? confirmName;

  @override
  State<TrashButton> createState() => _TrashButtonState();
}

class _TrashButtonState extends State<TrashButton> {
  bool undeleted = true;

  Future<void> _confirmedDelete(BuildContext context) async {
    return showDialog<void>(
      context: context,
      //barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return MySimpleAlertBox(
          actions: <Widget>[
            DismissTextButton(),
            TextButton(
                onPressed: () {
                  _delete();
                  Navigator.of(context).pop();
                },
                child: Text(S.of(context).validateDeletionSure))
          ],
          title: 'Sicher?',
          bodyLines: [
            '${widget.confirmName != null ? '"' + widget.confirmName! + '"' : ''}' +
                S.of(context).validateDeletionPromtHeadline,
            S.of(context).validateDeletionPromtWarning
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
          if (widget.confirmationNeeded)
            _confirmedDelete(context);
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
                return Rotating(child: Icon(Icons.delete));
              default:
                return Icon(Icons.check);
            }
          }),
    );
  }
}
