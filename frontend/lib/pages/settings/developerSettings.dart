import 'package:MBG_Inspektionen/generated/l10n.dart';
import 'package:MBG_Inspektionen/options.dart';
import 'package:MBG_Inspektionen/widgets/namedToggle.dart';
import 'package:flutter/material.dart';

class DeveloperSettings extends StatelessWidget {
  const DeveloperSettings({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(S.of(context).developerOptions)),
      body: ListView(
        children: [
          // NamedToggle(name: 'x', initiallyOn: false),
          ...Options().setteableBools().entries.map((x) {
            final name = x.key;
            final v = x.value;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: NamedToggle(
                name: name,
                initiallyOn: v.item1(),
                onChanged: (bool newValue) {
                  v.item2(newValue);
                },
              ),
            );
          }).toList(),
          Container(
            height: 100,
          )
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Options().store();
          Navigator.of(context).pop();
        },
        child: Icon(Icons.save),
      ),
    );
  }
}
