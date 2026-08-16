import 'package:MBG_Inspektionen/options.dart';
import 'package:MBG_Inspektionen/widgets/mySimpleAlertBox.dart';
import 'package:flutter/material.dart';

import 'package:MBG_Inspektionen/l10n/locales.dart';

class PopUpActionbutton extends StatelessWidget {
  final Widget collapsedChild;
  final Widget Function(Function()) expandedChild;

  //XXX: could blur background

  final EdgeInsets padding;

  const PopUpActionbutton({
    Key? key,
    this.collapsedChild = const Icon(Icons.add),
    required this.expandedChild,
    this.padding = const EdgeInsets.all(15),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: () {
        showDialog(
          context: context,
          builder: (context) => Scaffold(
            body: Container(
              padding: padding,
              child: expandedChild(() => Navigator.of(context).pop()),
            ),
          ),
        );
      },
      child: collapsedChild,
    );
  }
}

extension Unique<E, Id> on List<E> {
  List<E> unique([Id Function(E element)? id, bool inplace = true]) {
    final ids = Set();
    var list = inplace ? this : List<E>.from(this);
    list.retainWhere((x) => ids.add(id != null ? id(x) : x as Id));
    return list;
  }
}

mixin JsonExtractable on Widget {
  String get name => "";
  dynamic get json;
}

/*class JsonExtractableBuilder extends JsonExtractable {
  final String name;
  final Map<String, dynamic> json;
  JsonExtractableBuilder
  @override
  Widget build(BuildContext context) {
    throw UnimplementedError();
  }
}*/

class Adder extends StatelessWidget implements JsonExtractable {
  final String name;
  final Function(Map<String, dynamic>)? onSet;
  final Function()? onCancel;
  final String? title;

  final List<JsonExtractable> children;

  /// the data for each [TextField],
  /// ensure that all [InputData.varName]s are unique
  final List<InputData> textfieldList;
  final List<TextEditingController> _textfieldControllerList;
  // final List<FocusNode> _textfield_focusnode_list;

  final Map<String, Map<String, dynamic>> json;

  Adder(
    this.name, {
    this.onSet,
    this.onCancel,
    this.title,
    this.textfieldList = const [],
    this.children = const [],
  })  : assert(textfieldList ==
            textfieldList
                .unique((x) => x.varName)), //all varnames need to be unique
        this._textfieldControllerList =
            textfieldList.map((tf) => TextEditingController()).toList(),
        // this._textfield_focusnode_list =
        //     textfield_list.map((tf) => FocusNode()).toList(),
        this.json = {name: {}};

  // ignore: unused_element
  Future<void> _alert(BuildContext context) async {
    return showDialog<void>(
      barrierColor: Colors.black54,

      context: context,
      //barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return MySimpleAlertBox(
          actions: <Widget>[
            DismissTextButton(),
          ],
          bodyLines: [S.of(context).addingDataTryAgain],
          title: S.of(context).addingDataSomethingWrong,
        );
      },
    );
  }

  bool set(context) {
    if (!_formKey.currentState!.validate()) {
      //removed for now since formdata validate already shows problem
      // _alert(context);
      return false;
    }

    for (var i = 0; i < textfieldList.length; i++) {
      json[name]![textfieldList[i].varName] =
          textfieldList[i].postProcess(_textfieldControllerList[i].text);
    }
    children.forEach((child) {
      json[name]![child.name] = child.json;
    });
    onSet?.call(json);
    return true;
  }

  //XXX: i kinda feel bad about a static key, wouldnt all adders have the same key now?
  // so never ever have two adders in one context i guess
  // as seen [here](https://stackoverflow.com/a/64426900) though
  static final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: title == null ? null : AppBar(title: Text(title!)),
      body: Align(
        alignment: Alignment.bottomCenter,
        child: SingleChildScrollView(
          reverse: true,
          child: Form(
            key: _formKey,

            // autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                // Spacer(),
                ...children,
                ...List.generate(textfieldList.length, (i) {
                  _textfieldControllerList[i].value = TextEditingValue(
                    text: textfieldList[i].value ?? "",
                  );
                  return _Input(
                    // initialValue: textfieldList[i].value,
                    hint: textfieldList[i].hint,
                    isFirst: i == 0,
                    isLast: i == textfieldList.length - 1,
                    // onDone: (name) {
                    //   try {
                    //     //TextInputAction.next;
                    //     FocusScope.of(context)
                    //         .requestFocus(_textfield_focusnode_list[i + 1]);
                    //   } catch (e) {
                    //     FocusScope.of(context)
                    //         .requestFocus(_textfield_focusnode_list[0]);
                    //   }
                    // },
                    // fn: _textfield_focusnode_list[i],
                    c: _textfieldControllerList[i],
                    validator: textfieldList[i].verify,
                    dropdown: textfieldList[i].dropdown,
                  );
                }),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SafeArea(
          top: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              _PaddedButton(
                icon: Icons.cancel_outlined,
                onPressed: onCancel,
              ),
              //if (textfield_list.isNotEmpty) _mainField(set),
              _PaddedButton(
                icon: Icons.check_circle_outline,
                onPressed: () {
                  if (set(context)) onCancel?.call(); //as requested by #118
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaddedButton extends StatelessWidget {
  const _PaddedButton({
    Key? key,
    required this.icon,
    required this.onPressed,
  }) : super(key: key);

  final IconData icon;
  final Function()? onPressed;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(7.0),
        child: IconButton(
          color: Color(0xFF616161),
          iconSize: 60,
          //backgroundColor: Theme.of(context).canvasColor,
          onPressed: () {
            onPressed?.call();
          },
          icon: Icon(
            icon,
            // color: Theme.of(context).primaryColor,
          ),
        ),
      );
}

class _Input extends StatefulWidget {
  const _Input({
    Key? key,
    this.isFirst = false,
    this.isLast = false,
    required this.hint,
    this.validator = InputData.nonempty,
    required this.c,
    this.dropdown = const [],
  }) : super(key: key);

  final String? Function(String? text) validator;
  final bool isFirst;
  final bool isLast;
  final String hint;
  final TextEditingController c;
  final List<String> dropdown;

  @override
  State<_Input> createState() => _InputState();
}

class _InputState extends State<_Input> {
  bool _isOpen = false;

  void _setDropdownOpen(bool isOpen) {
    if (!mounted || _isOpen == isOpen) return;
    setState(() => _isOpen = isOpen);
  }

  @override
  Widget build(BuildContext context) {
    final bool hasSuggestions = widget.dropdown.isNotEmpty;

    return Container(
      padding: const EdgeInsets.only(top: 10, left: 20, right: 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TextFormField(
              controller: widget.c,
              minLines: 1,
              maxLines: 5,
              validator: widget.validator,
              autofocus: widget.isFirst,
              textInputAction: widget.isLast ? null : TextInputAction.next,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: Design.mainBorderRadius,
                ),
                labelText: widget.hint,
              ),
            ),
          ),
          if (hasSuggestions)
            Padding(
              padding: const EdgeInsets.only(left: 0, top: 2),
              child: SizedBox(
                width: 40,
                height: 40,
                child: PopupMenuButton<String>(
                  key: ValueKey('adder.dropdown.button.${widget.hint}'),
                  tooltip: widget.hint,
                  padding: EdgeInsets.zero,
                  position: PopupMenuPosition.over,
                  offset: const Offset(-160, -250),
                  requestFocus: false,
                  constraints: const BoxConstraints(
                    minWidth: 200,
                    maxWidth: 240,
                    maxHeight: 250,
                  ),
                  onOpened: () => _setDropdownOpen(true),
                  onCanceled: () => _setDropdownOpen(false),
                  onSelected: (value) {
                    widget.c.text = value;
                    _setDropdownOpen(false);
                  },
                  itemBuilder: (context) => widget.dropdown
                      .map(
                        (value) => PopupMenuItem<String>(
                          key: ValueKey('adder.dropdown.option.$value'),
                          value: value,
                          child: Text(
                            value,
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      )
                      .toList(),
                  icon: Icon(
                    _isOpen ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class InputData {
  /// under which name to store the result
  final String varName;

  final String? value;

  /// the hint the user gets to see
  final String hint;

  /// a function on whether the current [text] is valid (correct set of characters etc)
  /// shall return null if correct and an error-string otherwise
  final String? Function(String? text) verify;

  final String? Function(String? text) postProcess;

  final List<String> dropdown;

  InputData(this.varName,
      {this.postProcess = noSpacesAtEndAndNoSlashes,
      required this.hint,
      this.value,
      this.verify = defaultVerification,
      this.dropdown = const []});

  static const defaultVerification = nonempty;

  static String? nonempty(String? str) => (str != null && str.isNotEmpty)
      ? null
      : S.current!.addingDataEnterSomethingHere;

  static String? noSpacesAtEnd(String? str) => (str?.trim());
  static String? cutSlashinString(String? str) => (str
      ?.replaceAll("/", "")
      .replaceAll("\\", "")
      .replaceAll(":", "")
      .replaceAll("*", "")
      .replaceAll("?", "")
      .replaceAll("\"", "")
      .replaceAll("", "")
      .replaceAll("<", "")
      .replaceAll(">", "")
      .replaceAll("-", "")
      .replaceAll("&", "")
      .replaceAll("|", ""));

  static String? noSpacesAtEndAndNoSlashes(String? str) =>
      noSpacesAtEnd(cutSlashinString(str));

  static String? alwaysCorrect(String? str) => null;
}
