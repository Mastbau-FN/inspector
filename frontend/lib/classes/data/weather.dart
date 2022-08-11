// ignore_for_file: non_constant_identifier_names

import 'package:json_annotation/json_annotation.dart';

enum Weather {
  @JsonValue('Regen')
  rain,
  @JsonValue('Sonne')
  sunny,
  @JsonValue('Wolken')
  clouds,
  @JsonValue('Sonnig/Bewölkt')
  kinda_cloudy_but_some_sunshine,
}

enum WindPower {
  @JsonValue('windstill')
  none,
  @JsonValue('mäßig')
  medium,
  @JsonValue('stark')
  strong,
}

enum WindDirection {
  @JsonValue('N')
  north,
  @JsonValue('NNO')
  north_north_east,
  @JsonValue('NO')
  north_east,
  @JsonValue('ONO')
  east_north_east,
  @JsonValue('O')
  east,
  @JsonValue('OSO')
  east_south_east,
  @JsonValue('SO')
  south_east,
  @JsonValue('SSO')
  south_south_east,
  @JsonValue('S')
  south,
  @JsonValue('SSW')
  south_south_west,
  @JsonValue('SW')
  south_west,
  @JsonValue('WSW')
  west_south_west,
  @JsonValue('W')
  west,
  @JsonValue('WNW')
  west_north_west,
  @JsonValue('NW')
  north_west,
  @JsonValue('NNW')
  north_north_west,
}

// String wd2string(WindDirection wd) =>

class WeatherData {
  int? temperature;
  Weather? weather;
  WindPower? wind_speed;
  WindDirection? wind_direction;

  WeatherData(
      {this.temperature, this.weather, this.wind_speed, this.wind_direction});
}
