import 'package:MBG_Inspektionen/classes/data/weather.dart';
import 'package:flutter/material.dart';
import 'package:weather_icons/weather_icons.dart';

import 'helpers.dart';

class WeatherSet extends StatelessWidget {
  final Function(WeatherData) onChanged;
  final WeatherData weatherData;
  const WeatherSet(
      {required this.weatherData, required this.onChanged, Key? key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container();
  }
}

class WeatherPreview extends StatelessWidget {
  final WeatherData weatherData;
  const WeatherPreview({required this.weatherData, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container();
  }
}

class WeatherIcon extends StatelessWidget {
  final Weather weather;
  const WeatherIcon({required this.weather, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Icon(weather2icon(weather));
  }
}
