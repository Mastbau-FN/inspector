import 'package:flutter/material.dart';
import 'package:mastbau_inspector/pages/dropdown/dropdownModel.dart';

class TransformeableActionbutton extends StatefulWidget {
  final Function(Data?)? onAdd;

  const TransformeableActionbutton({Key? key, this.onAdd}) : super(key: key);

  @override
  TransformeableActionbuttonState createState() =>
      TransformeableActionbuttonState();
}

class TransformeableActionbuttonState
    extends State<TransformeableActionbutton> {
  bool isClicked = false;
  bool wasClicked = false;

  void popupGroup() {
    setState(() {
      isClicked = true;
    });
    Future.delayed(Duration(milliseconds: 400), () {
      setState(() {
        wasClicked = true;
      });
    });
  }

  void cancel() {
    setState(() {
      wasClicked = false;
      isClicked = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: popupGroup,
      child: AnimatedContainer(
        decoration: BoxDecoration(
          boxShadow: isClicked
              ? [
                  BoxShadow(
                      color: Theme.of(context).backgroundColor,
                      blurRadius: 25,
                      spreadRadius: 10)
                ]
              : [
                  BoxShadow(
                      color: Colors.black,
                      blurRadius: 15,
                      offset: Offset.fromDirection(1.3, 7),
                      spreadRadius: -4)
                ],
          color: isClicked
              ? Theme.of(context).cardColor
              : Theme.of(context).accentColor,
          borderRadius:
              isClicked ? BorderRadius.circular(20) : BorderRadius.circular(30),
        ),
        curve: Curves.easeInOutCubic,
        duration: Duration(milliseconds: 400),
        height: isClicked ? 350 : 60,
        width: isClicked ? MediaQuery.of(context).size.width - 30 : 60,
        child: wasClicked
            ? Container(
                child: GroupEditor(
                  update: (group) {
                    widget.onAdd?.call(group);
                    cancel();
                  },
                  abort: cancel,
                ),
              )
            : Icon(
                Icons.group_add,
                color: Theme.of(context).backgroundColor,
              ),
      ),
    );
  }
}

//TODO: nicht nur 3 namen sondern wie eingestellt
class GroupEditor extends StatelessWidget {
  final FocusNode name2 = FocusNode();
  final FocusNode name3 = FocusNode();

  final name1C = TextEditingController();
  final name2C = TextEditingController();
  final name3C = TextEditingController();
  final gNameC = TextEditingController();

  final Function(Data?)? update;
  final Function()? abort;

  List<String> names = [];

  GroupEditor({this.update, this.abort});

  @override
  Widget build(BuildContext context) {
    Future<void> _fillNames() async {
      return showDialog<void>(
        context: context,
        //barrierDismissible: false, // user must tap button!
        builder: (BuildContext context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20.0),
            ),
            title: Text('Da fehlt wohl jemand'),
            content: SingleChildScrollView(
              child: ListBody(
                children: <Widget>[
                  Text('Es sind doch immer 3 in einer Gruppe'),
                  Text('Du hast wohl nicht genug eingegeben.'),
                ],
              ),
            ),
            actions: <Widget>[
              FlatButton(
                child: Text(
                  'Oops',
                  style: TextStyle(color: Theme.of(context).primaryColor),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
    }

    void set() {
      bool hasName = gNameC.text.isNotEmpty;
      bool bedingung = name1C.text.length > 0 &&
          name2C.text.length > 0 &&
          name3C.text.length > 0;
      if (bedingung) {
        names = [name1C.text, name2C.text, name3C.text];
        List kids = List.generate(names.length, (i) {
          return names[i];
        });
        update?.call(
          null, /*TODO */
        );
      } else {
        _fillNames();
      }
    }

    Widget input({onDone, fn, c}) {
      return Container(
        padding: EdgeInsets.only(top: 10, left: 20, right: 20),
        child: TextField(
          maxLength: 15,
          focusNode: fn,
          textInputAction: TextInputAction.next,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white70, width: 1)),
            hintText: "Schüler Name",
            hintStyle: TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w100,
              fontSize: 17,
            ),
          ),
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
          textAlign: TextAlign.center,
          onSubmitted: onDone,
          controller: c,
        ),
      );
    }

    return Column(
      children: <Widget>[
        input(
          onDone: (name) {
            FocusScope.of(context).requestFocus(name2);
          },
          c: name1C,
        ),
        input(
          onDone: (name) {
            FocusScope.of(context).requestFocus(name3);
          },
          fn: name2,
          c: name2C,
        ),
        input(
          onDone: (name) {
            set();
          },
          fn: name3,
          c: name3C,
        ),
        Container(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            RaisedButton(
              elevation: 8,
              padding: EdgeInsets.all(15),
              color: Theme.of(context).canvasColor,
              shape: CircleBorder(),
              onPressed: () {
                abort?.call();
                debugPrint("aborted");
              },
              child: Icon(
                Icons.cancel,
                color: Theme.of(context).primaryColor,
              ),
            ),
            Container(
              width: 130,
              child: TextField(
                maxLength: 20,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white, width: 2),
                      borderRadius: BorderRadius.circular(15)),
                  enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white54, width: 1),
                      borderRadius: BorderRadius.circular(15)),
                  hintText: "-Gruppename-",
                  hintStyle: TextStyle(
                    color: Colors.white60,
                    fontWeight: FontWeight.w300,
                    fontSize: 19,
                  ),
                ),
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
                textAlign: TextAlign.center,
                onSubmitted: (x) {
                  set();
                },
                controller: gNameC,
              ),
            ),
            RaisedButton(
              elevation: 8,
              padding: EdgeInsets.all(15),
              color: Theme.of(context).canvasColor,
              shape: CircleBorder(),
              onPressed: () {
                set();
              },
              child: Icon(
                Icons.check_circle,
                color: Theme.of(context).primaryColor,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
