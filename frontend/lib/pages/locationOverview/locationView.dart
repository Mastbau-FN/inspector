import 'package:flutter/material.dart';
import 'package:mastbau_inspector/classes/user.dart';
import 'package:mastbau_inspector/fragments/MainDrawer.dart';
import 'package:mastbau_inspector/pages/loadingscreen/loadingView.dart';
import 'package:mastbau_inspector/pages/login/loginModel.dart';
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
      ),
    );
  }
}
