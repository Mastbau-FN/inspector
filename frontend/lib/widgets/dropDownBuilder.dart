import 'package:flutter/material.dart';

import '../classes/data/weather.dart';
import '../fragments/weather/helpers.dart';

class DropDownBuilder<T> extends StatefulWidget {
  final List<T?> possibilities;
  final Widget Function(T?) builder;
  final T? selected;
  final Function(T) onChanged;
  DropDownBuilder({
    Key? key,
    required this.possibilities,
    required this.builder,
    required this.selected,
    required this.onChanged,
  }) : super(key: key);

  @override
  State<DropDownBuilder<T>> createState() => _DropDownBuilderState<T>();
}

class _DropDownBuilderState<T> extends State<DropDownBuilder<T>> {
  T? _selected;
  @override
  void initState() {
    _selected = widget.selected;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return DropdownButton<T>(
      value: _selected,
      icon: Container(), //const Icon(Icons.arrow_downward),
      // elevation: 16,
      // style: const TextStyle(color: Colors.deepPurple),
      underline: Container(
        height: 0,
        color: Theme.of(context).primaryColor,
      ),
      onChanged: (T? newValue) {
        setState(() {
          _selected = newValue;
        });
      },
      items: widget.possibilities.map<DropdownMenuItem<T>>((T? value) {
        return DropdownMenuItem<T>(
          value: value,
          child: widget.builder(value),
        );
      }).toList(),
    );
  }
}
