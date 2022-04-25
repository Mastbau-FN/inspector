import 'package:MBG_Inspektionen/classes/data/weather.dart';
import 'package:MBG_Inspektionen/fragments/weather/editableWeatherView.dart';
import 'package:flutter/material.dart';
import 'package:weather_icons/weather_icons.dart';

IconData weather2icon(Weather? w) => w == Weather.slightly_rainy
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
                                        : WeatherIcons.na;

String windDir2string(WindDirection? wd) {
  switch (wd) {
    case WindDirection.north:
      return "N";
    case WindDirection.north_north_east:
      return "NNO";
    case WindDirection.north_east:
      return "NO";
    case WindDirection.east_north_east:
      return "ONO";
    case WindDirection.east:
      return "O";
    case WindDirection.east_south_east:
      return "OSO";
    case WindDirection.south_east:
      return "SO";
    case WindDirection.south_south_east:
      return "SSO";
    case WindDirection.south:
      return "S";
    case WindDirection.south_south_west:
      return "SSW";
    case WindDirection.south_west:
      return "SW";
    case WindDirection.west_south_west:
      return "WSW";
    case WindDirection.west:
      return "W";
    case WindDirection.north_west:
      return "NW";
    case WindDirection.north_north_west:
      return "NNW";
    default:
      return "";
  }
}

IconData windDir2icon(WindDirection? wd) => wd == null
    ? WeatherIcons.na
    : WeatherIcons.fromString('towards_${windDir2string(wd).toLowerCase()}');
