import 'package:MBG_Inspektionen/classes/data/weather.dart';
import 'package:MBG_Inspektionen/widgets/dropDownBuilder.dart';
import 'package:flutter/material.dart';
import 'package:weather_icons/weather_icons.dart';

import 'helpers.dart';

class WeatherSet extends StatefulWidget {
  final Function(WeatherData) onChanged;
  final WeatherData weatherData;
  const WeatherSet(
      {required this.weatherData, required this.onChanged, Key? key})
      : super(key: key);

  @override
  State<WeatherSet> createState() => _WeatherSetState();
}

class _WeatherSetState extends State<WeatherSet> {
  bool isInEditMode = false;
  @override
  Widget build(BuildContext context) {
    return !isInEditMode
        ? WeatherPreview(
            weatherData: widget.weatherData,
            onChanged: widget.onChanged,
          )
        : Container();
  }
}

class WeatherPreview extends StatelessWidget {
  final Function(WeatherData) onChanged;
  final WeatherData weatherData;
  const WeatherPreview(
      {required this.weatherData, required this.onChanged, Key? key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        WeatherIcon(
          weather: weatherData.weather,
          onChanged: (w) {
            //XXX: stateful und setState besser?
            weatherData.weather = w;
            onChanged(weatherData);
          },
        ),
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
        : Icon(WeatherIcons.na);
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
  final Function(Weather?) onChanged;
  const WeatherIcon({
    required this.weather,
    required this.onChanged,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DropDownBuilder<Weather>(
        possibilities: [null, ...Weather.values],
        builder: (weather) => Icon(weather2icon(weather)),
        selected: weather,
        onChanged: onChanged);
  }
}
