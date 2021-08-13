import 'package:flutter/material.dart';

class BackButton extends StatelessWidget {
  final bool preventPopping;
  final Function? onPressed;
  const BackButton({Key? key, this.preventPopping = false, this.onPressed})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      child: IconButton(
        icon: Icon(Icons.arrow_left),
        onPressed: () {
          onPressed?.call();
          if (!preventPopping) Navigator.pop(context);
        },
      ),
    );
  }
}
