import 'package:json_annotation/json_annotation.dart';

enum Weather {
  @JsonValue('Niederschlag')
  rain,
  @JsonValue('Regen')
  rain_snow,
  @JsonValue('Schnee')
  snow,
  @JsonValue('Sonne')
  sun,
  @JsonValue('Sonnig')
  sun_sunny,
  @JsonValue('Wolken')
  clouds,
  @JsonValue('Wind')
  wind,
  @JsonValue('Gewitter')
  thunderstorm,
  @JsonValue('Hagel')
  hail,
  @JsonValue('Nebel')
  fog,
  @JsonValue('Sturm')
  storm,
}

enum WindPower {
  @JsonValue('0')
  none,
  @JsonValue('1')
  light,
  @JsonValue('2')
  medium,
  @JsonValue('3')
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
