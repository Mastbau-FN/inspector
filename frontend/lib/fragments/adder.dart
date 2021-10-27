import 'package:flutter/material.dart';
import 'package:mastbau_inspector/pages/dropdown/dropdownModel.dart';

//should be held up to date with FloatingActionButton
const BoxConstraints _kSizeConstraints = BoxConstraints.tightFor(
  width: 56.0,
  height: 56.0,
);

class TransformeableActionbutton extends StatefulWidget {
  final Widget collapsedChild;
  final Widget Function(Function()) expandedChild;
  final double expandedHeight;
  final Function(Data?)? onAdd;

  final EdgeInsets padding;

  const TransformeableActionbutton({
    Key? key,
    this.onAdd,
    this.collapsedChild = const Icon(Icons.add),
    required this.expandedChild,
    this.padding = const EdgeInsets.all(15),
    this.expandedHeight = 400,
  }) : super(key: key);

  @override
  TransformeableActionbuttonState createState() =>
      TransformeableActionbuttonState();
}

class TransformeableActionbuttonState
    extends State<TransformeableActionbutton> {
  bool isClicked = false;
  bool wasClicked = false;

  final transition_ms = 400;

  void popupGroup() {
    setState(() {
      isClicked = true;
    });
    Future.delayed(Duration(milliseconds: transition_ms), () {
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
    ThemeData theme = Theme.of(context);
    FloatingActionButtonThemeData ftheme =
        Theme.of(context).floatingActionButtonTheme;
    double radius =
        (ftheme.sizeConstraints?.maxWidth ?? _kSizeConstraints.maxWidth) / 2;
    return GestureDetector(
      onTap: popupGroup,
      child: AnimatedContainer(
        key: UniqueKey(),
        //padding: isClicked ? widget.padding : EdgeInsets.all(0), //not needed, since the floatingAction Button from scaffold is already padded
        decoration: BoxDecoration(
          boxShadow: isClicked
              ? [
                  BoxShadow(
                      color: theme.colorScheme.secondary.withAlpha(30),
                      blurRadius: radius * .4,
                      spreadRadius: 0)
                ]
              : [],
          color: isClicked
              ? theme.cardColor
              : ftheme.backgroundColor ?? theme.colorScheme.primary,
          borderRadius: BorderRadius.circular(radius),
        ),
        curve: Curves.easeInOutCubic,
        duration: Duration(milliseconds: transition_ms),
        height: isClicked
            ? widget.expandedHeight
            : ftheme.sizeConstraints?.maxHeight ?? _kSizeConstraints.maxHeight,
        width: isClicked
            ? MediaQuery.of(context).size.width -
                widget.padding.left -
                widget.padding.right
            : ftheme.sizeConstraints?.maxWidth ?? _kSizeConstraints.maxWidth,
        child:
            isClicked /*wasClicked*/ //Yes this makes  layout err, but it looks better in prod, could use wasClicked and for better transition the isClicked below
                ? Container(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: widget.expandedChild(cancel),
                    ),
                  )
                : /*isClicked
                ? Container()
                : */
                Container(
                    child: FloatingActionButton(
                      child: widget.collapsedChild,
                      onPressed: popupGroup,
                    ),
                  ),
      ),
    );
  }
}

/*class Cancelable {
  final Function(Function) builder;
  const Cancelable({
    Key? key,
    required this.builder,
  });

  Widget withcancel(Function onCancel) => builder(onCancel);
}*/

//TODO: nicht nur 3 namen sondern wie eingestellt
class Adder extends StatelessWidget {
  final Function(Data?)? onSet;
  final Function()? onCancel;

  final List<InputData> textfield_list;
  final List<TextEditingController> _textfield_controller_list;
  final List<FocusNode> _textfield_focusnode_list;

  List<String> names = [];

  Adder({this.onSet, this.onCancel, this.textfield_list = const []})
      : this._textfield_controller_list =
            textfield_list.map((tf) => TextEditingController()).toList(),
        this._textfield_focusnode_list =
            textfield_list.map((tf) => FocusNode()).toList();

  @override
  Widget build(BuildContext context) {
    Future<void> _alert() async {
      return showDialog<void>(
        context: context,
        //barrierDismissible: false, // user must tap button!
        builder: (BuildContext context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20.0),
            ),
            title: Text('Noch nicht unterstützt'),
            content: SingleChildScrollView(
              child: ListBody(
                children: <Widget>[
                  Text('sorry, ich arbeite dran'),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                child: Text(
                  'okay..',
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
      if (textfield_list.every((element) => element.verify(
          //okay the indexOf workaround is pretty bad (O(n^2)), make the every iteretion indexed and it'll be O(n). (but the list shall be rather short so np)
          _textfield_controller_list[textfield_list.indexOf(element)].text))) {
        onSet?.call(
          null, /*TODO: generate data or whatever from texts */
        );
      } else {
        _alert();
      }
    }

    Widget _paddedButton(IconData icon, Function()? onPressed) => Padding(
          padding: const EdgeInsets.all(15.0),
          child: FloatingActionButton(
            backgroundColor: Theme.of(context).canvasColor,
            onPressed: () {
              onPressed?.call();
            },
            child: Icon(
              icon,
              color: Theme.of(context).primaryColor,
            ),
          ),
        );

    Container _mainField(void set()) {
      return Container(
        width: 130,
        child: TextField(
          //maxLength: 20,
          textInputAction: TextInputAction.next,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.primary, width: 2),
                borderRadius: BorderRadius.circular(15)),
            enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(
                    color: Theme.of(context)
                        .colorScheme
                        .onBackground
                        .withAlpha(50),
                    width: 1),
                borderRadius: BorderRadius.circular(15)),
            hintText: textfield_list[0].hint,
            hintStyle: TextStyle(
              fontWeight: FontWeight.w300,
              fontSize: 19,
            ),
          ),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
          textAlign: TextAlign.center,
          onSubmitted: (x) {
            set();
          },
          focusNode: _textfield_focusnode_list[0],
          controller: _textfield_controller_list[0],
        ),
      );
    }

    Widget _input({
      bool isBetterthantherest = false,
      required String hint,
      required Function(String) onDone,
      required FocusNode fn,
      required TextEditingController c,
    }) {
      return Container(
        padding: EdgeInsets.only(top: 10, left: 20, right: 20),
        child: TextField(
          autofocus: isBetterthantherest,
          focusNode: fn,
          textInputAction: TextInputAction.next,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(
                    color: Theme.of(context)
                        .colorScheme
                        .onBackground
                        .withAlpha(50),
                    width: 1)),
            hintText: hint,
            hintStyle: TextStyle(
              fontWeight: FontWeight.w100,
              fontSize: 17,
            ),
          ),
          style: TextStyle(
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
        Spacer(),
        ...List.generate(
          textfield_list.length - 1,
          (i) => _input(
            isBetterthantherest: i ==
                0, //TODO: its buggy for some reason: crash on backbutton .. something something hero, focusnodes are somehow messed up
            hint: textfield_list[i + 1].hint,
            onDone: (name) {
              try {
                //TextInputAction.next;
                FocusScope.of(context)
                    .requestFocus(_textfield_focusnode_list[i + 2]);
              } catch (e) {
                FocusScope.of(context)
                    .requestFocus(_textfield_focusnode_list[0]);
              }
            },
            fn: _textfield_focusnode_list[i + 1],
            c: _textfield_controller_list[i + 1],
          ),
        ),
        Container(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            _paddedButton(Icons.cancel, onCancel),
            if (textfield_list.isNotEmpty) _mainField(set),
            _paddedButton(Icons.check_circle, set),
          ],
        ),
      ],
    );
  }
}

class InputData {
  final String hint;
  final bool Function(String text) verify;
  const InputData({required this.hint, required this.verify});
}
