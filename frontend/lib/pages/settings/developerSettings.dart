import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:MBG_Inspektionen/options.dart';
import 'package:MBG_Inspektionen/widgets/MyListTile1.dart';
import 'package:MBG_Inspektionen/widgets/namedToggle.dart';
import 'package:flutter/material.dart';
import 'package:MBG_Inspektionen/backend/offlineProvider.dart' as OP;

class DeveloperSettings extends StatelessWidget {
  const DeveloperSettings({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
          AppBar(title: Text(AppLocalizations.of(context)!.developerOptions)),
      body: ListView(
        children: [
          MyCardListTile1(
            text: 'total reset',
            onTap: () => OP.deleteAll(),
          ),
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
