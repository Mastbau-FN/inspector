import 'package:flutter/material.dart';

class NulleableToggle extends StatefulWidget {
  const NulleableToggle({Key? key, this.onSelected, this.isSelected})
      : super(key: key);
  final bool? isSelected;
  final Function(bool?)? onSelected;

  @override
  State<NulleableToggle> createState() => _NulleableToggleState();
}

class _NulleableToggleState extends State<NulleableToggle> {
  @override
  void initState() {
    _isSelected = [
      widget.isSelected == true,
      widget.isSelected == null,
      widget.isSelected == false
    ];
    super.initState();
  }

  List<bool> _isSelected = [false, false, false];
  @override
  Widget build(BuildContext context) {
    return ToggleButtons(
      renderBorder: false,
      children: <Widget>[
        Icon(Icons.check),
        Icon(Icons.question_mark),
        Icon(Icons.close),
      ],
      onPressed: (int index) {
        setState(() {
          if (!_isSelected[index])
            widget.onSelected
                ?.call(index == 0 ? true : (index == 1 ? null : false));
          for (int buttonIndex = 0;
              buttonIndex < _isSelected.length;
              buttonIndex++) {
            if (buttonIndex == index) {
              _isSelected[buttonIndex] = true;
            } else {
              _isSelected[buttonIndex] = false;
            }
          }
        });
      },
      isSelected: _isSelected,
    );
  }
}
