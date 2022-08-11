import 'package:flutter/material.dart';

class NamedToggle extends StatefulWidget {
  NamedToggle(
      {Key? key, required this.name, required this.initiallyOn, this.onChanged})
      : super(key: key);

  final String name;
  final bool initiallyOn;
  final Function(bool)? onChanged;

  @override
  State<NamedToggle> createState() => _NamedToggleState();
}

class _NamedToggleState extends State<NamedToggle> {
  late bool _isSelected;
  @override
  void initState() {
    super.initState();
    _isSelected = widget.initiallyOn;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(widget.name),
        Switch(value: _isSelected, onChanged: widget.onChanged),
      ],
    );
  }
}
