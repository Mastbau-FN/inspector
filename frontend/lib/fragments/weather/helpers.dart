import 'package:MBG_Inspektionen/classes/data/weather.dart';
import 'package:flutter/material.dart';
import 'package:weather_icons/weather_icons.dart';

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
