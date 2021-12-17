import 'package:MBG_Inspektionen/widgets/rotating.dart';
import 'package:flutter/material.dart';

class LoadingView extends StatelessWidget {
  const LoadingView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      child: AspectRatio(
        aspectRatio: 1,
        child: Rotating(
          child: AspectRatio(
            aspectRatio: 1,
            child: Image(
              image: AssetImage('lib/assets/icon.png'),
            ),
          ),
        ),
      ),
    );
  }
}

class LoadingPage extends StatelessWidget {
  const LoadingPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("loading..."),
      ),
      body: Padding(
        padding: const EdgeInsets.all(80.0),
        child: LoadingView(),
      ),
    );
  }
}
