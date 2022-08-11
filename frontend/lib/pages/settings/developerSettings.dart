import 'package:MBG_Inspektionen/widgets/namedToggle.dart';
import 'package:flutter/material.dart';

class DeveloperSettings extends StatelessWidget {
  const DeveloperSettings({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [NamedToggle(name: name, initiallyOn: initiallyOn)],
    );
  }
}
