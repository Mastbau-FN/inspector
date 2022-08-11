import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../pages/login/loginModel.dart';
import 'MyListTile1.dart';

class OpenNewViewTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget newView;
  final bool supplyLoginModel;

  const OpenNewViewTile({
    this.icon = Icons.open_in_full,
    required this.title,
    required this.newView,
    this.supplyLoginModel = false,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MyCardListTile1(
      icon: icon,
      text: title,
      onTap: () {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (newcontext) => supplyLoginModel
                ? ChangeNotifierProvider<LoginModel>.value(
                    value: Provider.of<LoginModel>(context),
                    child: newView,
                  )
                : newView,
          ),
        );
      },
    );
  }
}
