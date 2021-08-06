import 'package:flutter/material.dart';

class ErrorText extends StatelessWidget {
  final String? error;
  final Color color;

  /// whether to remove the "Exception: " with which most exceptions start
  final bool removeException;
  const ErrorText(this.error,
      {this.color = Colors.red, Key? key, this.removeException = true})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.error_outline_rounded,
          color: color,
        ),
        SizedBox(
          width: 5,
        ),
        Text(
          // removes the the "Exception: " if wanted and the string matches
          error?.substring(
                  removeException && error?.substring(0, 11) == "Exception: "
                      ? 11
                      : 0) ??
              "",
          style: TextStyle(color: color),
        )
      ],
    );
  }
}
