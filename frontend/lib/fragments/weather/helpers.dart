import 'package:MBG_Inspektionen/classes/data/weather.dart';
import 'package:MBG_Inspektionen/fragments/weather/editableWeatherView.dart';
import 'package:flutter/material.dart';
import 'package:weather_icons/weather_icons.dart';
import 'package:json_annotation/json_annotation.dart';

IconData weather2icon(Weather? w) => w == Weather.rain
    ? WeatherIcons.rain
    : w == Weather.kinda_cloudy_but_some_sunshine
        ? WeatherIcons.day_cloudy
        : w == Weather.sunny
            ? WeatherIcons.day_sunny
            : w == Weather.clouds
                ? WeatherIcons.cloud
                : WeatherIcons.na;

const $WindDirectionEnumMap = {
  WindDirection.north: 'N',
  WindDirection.north_north_east: 'NNO',
  WindDirection.north_east: 'NO',
  WindDirection.east_north_east: 'ONO',
  WindDirection.east: 'O',
  WindDirection.east_south_east: 'OSO',
  WindDirection.south_east: 'SO',
  WindDirection.south_south_east: 'SSO',
  WindDirection.south: 'S',
  WindDirection.south_south_west: 'SSW',
  WindDirection.south_west: 'SW',
  WindDirection.west_south_west: 'WSW',
  WindDirection.west: 'W',
  WindDirection.west_north_west: 'WNW',
  WindDirection.north_west: 'NW',
  WindDirection.north_north_west: 'NNW',
};

String? windDir2string(WindDirection? wd) => $WindDirectionEnumMap[wd];

Widget windDir2icon(WindDirection? wd) => wd != null
    ? WindIcon.fromString(
        'towards_${windDir2string(wd)!.toLowerCase().replaceAll('o', 'e')}',
        fallback: WindIcon.from_ne)
    : WindIcon(
        degree: 4,
      );

//no idea why i'd need this but hey
WindDirection? string2windDir(String? s) =>
    ($WindDirectionEnumMap as Map<WindDirection?, String>)
        .entries
        .firstWhere((e) => e.value == s, orElse: () => MapEntry(null, 'null'))
        .key;
