import 'package:flutter/material.dart';
import 'package:mastbau_inspector/backend/api.dart';
import 'package:mastbau_inspector/classes/inspection_location.dart';
import 'package:mastbau_inspector/classes/user.dart';
import 'package:mastbau_inspector/fragments/MainDrawer.dart';
import 'package:mastbau_inspector/pages/loadingscreen/loadingView.dart';
import 'package:mastbau_inspector/pages/login/loginModel.dart';
import 'package:mastbau_inspector/widgets/MyListTile1.dart';
import 'package:mastbau_inspector/widgets/myExpandablelList.dart';
import 'package:provider/provider.dart';

class LocationView extends StatelessWidget {
  const LocationView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Consumer<LoginModel>(
          builder: (context, login, child) => FutureBuilder(
              future: login.user,
              builder: (context, AsyncSnapshot<DisplayUser?> snapshot) =>
                  (snapshot.hasData && snapshot.data != null)
                      ? _LocationView(
                          user: snapshot.data!,
                        )
                      : LoadingView())),
    );
  }
}

class _LocationView extends StatelessWidget {
  final DisplayUser user;
  const _LocationView({required this.user, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Scaffold(
        appBar: AppBar(
          title: Text('Inspektionen: ${user.toString()}'),
        ),
        drawer: MainDrawer(),
        body: FutureBuilder<List<InspectionLocation>>(
            future: Backend().getAllInspectionLocationsForCurrentUser(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done) {
                return ExpandablesListRadio(
                    children: snapshot.data!
                        .map((e) => locationDropDown(e))
                        .toList());
              }
              return ExpandablesListRadio.fake(3);
            }),
      ),
    );
  }

  ExpandableCard2 locationDropDown(InspectionLocation inspectionLocation) {
    return ExpandableCard2(
      title: inspectionLocation.pjName,
      children: [
        MyCardListTile1(
          text: "Prüfkategorien",
          onTap: () {
            //TODO
          },
        ),
        MyCardListTile1(
          text: "Fotos",
          onTap: () {
            //TODO
          },
        ),
        MyCardListTile1(
          text: "Infos",
          onTap: () {
            //TODO
          },
        ),
      ],
    );
  }
}
