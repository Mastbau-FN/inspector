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
    return Row(
      children: [
        WeatherIcon(weather: weatherData.weather),
        WindPreview(weatherData: weatherData),
        TemperaturePreview(temperature: weatherData.temperature),
      ],
    );
  }
}

class TemperaturePreview extends StatelessWidget {
  final int? temperature;
  const TemperaturePreview({required this.temperature, Key? key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return temperature != null
        ? Text(
            "$temperature°C",
            style: TextStyle(fontSize: 20),
          )
        : Container();
  }
}

class WindPreview extends StatelessWidget {
  final WeatherData weatherData;
  const WindPreview({required this.weatherData, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        WindDirectionIcon(dir: weatherData.wind_direction),
        WindSpeedIcon(windSpeed: weatherData.wind_speed)
      ],
    );
  }
}

class WindSpeedIcon extends StatelessWidget {
  final WindPower? windSpeed;
  const WindSpeedIcon({Key? key, required this.windSpeed}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Text(windSpeed == WindPower.none
        ? "windstill"
        : windSpeed == WindPower.medium
            ? "mäßiger wind"
            : windSpeed == WindPower.strong
                ? "starker wind"
                : "unbekannter wind");
  }
}

class WindDirectionIcon extends StatelessWidget {
  final WindDirection? dir;
  const WindDirectionIcon({Key? key, required this.dir}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Icon(windDir2icon(dir));
  }
}

class WeatherIcon extends StatelessWidget {
  final Weather? weather;
  const WeatherIcon({required this.weather, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Icon(weather2icon(weather));
  }
}
