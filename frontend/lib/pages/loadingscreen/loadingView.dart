import 'package:flutter/material.dart';
import 'dart:math' as math;

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

class Rotating extends StatefulWidget {
  final Widget child;

  const Rotating({required this.child, Key? key}) : super(key: key);

  @override
  _RotatingState createState() => _RotatingState();
}

class _RotatingState extends State<Rotating>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: Duration(seconds: 1))
          ..repeat();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (_, child) {
            return Transform.rotate(
              angle: _controller.value * 2 * math.pi,
              child: child,
            );
          },
          child: widget.child,
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
