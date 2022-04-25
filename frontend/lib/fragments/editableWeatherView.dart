import 'package:MBG_Inspektionen/classes/data/weather.dart';
import 'package:flutter/material.dart';
import 'package:weather_icons/weather_icons.dart';

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

IconData weather2icon(Weather w) => w == Weather.slightly_rainy
    ? WeatherIcons.rain_mix
    : w == Weather.rain
        ? WeatherIcons.rain
        : w == Weather.snow
            ? WeatherIcons.snow
            : w == Weather.sunny
                ? WeatherIcons.day_sunny
                : w == Weather.clouds
                    ? WeatherIcons.cloud
                    : w == Weather.wind
                        ? WeatherIcons.wind
                        : w == Weather.thunderstorm
                            ? WeatherIcons.thunderstorm
                            : w == Weather.hail
                                ? WeatherIcons.hail
                                : w == Weather.fog
                                    ? WeatherIcons.fog
                                    : w == Weather.storm
                                        ? WeatherIcons.strong_wind
                                        : Icons.question_mark;
