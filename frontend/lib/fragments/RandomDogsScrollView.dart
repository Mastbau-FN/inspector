import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class RandomDogsScrollView extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => _RandomDogsScrollViewState();
}

class _RandomDogsScrollViewState extends State<RandomDogsScrollView> {
  List<String> dogs = [];
  ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    get5dogs();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 400) {
        get5dogs();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: _scrollController,
      itemCount: dogs.length,
      itemBuilder: (context, index) {
        return Container(
          height: 200,
          child: Image.network(
            dogs[index],
            fit: BoxFit.fitWidth,
          ),
        );
      },
    );
  }

  getDogSrc() async {
    try {
      final res =
          await http.get(Uri.parse('https://dog.ceo/api/breeds/image/random'));
      if (res.statusCode == 200) {
        setState(() {
          dogs.add(json.decode(res.body)['message']);
        });
      } else {
        debugPrint("error");
      }
    } catch (err) {
      debugPrint("failed to load doggo: $err");
    }
  }

  get5dogs() {
    for (int i = 0; i < 5; i++) {
      getDogSrc();
    }
  }
}
