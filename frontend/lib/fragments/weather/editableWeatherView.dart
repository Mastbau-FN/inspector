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
        WindPreview(weatherData: weatherData, onChanged: onChanged),
        TemperaturePreview(
          temperature: weatherData.temperature,
          onChanged: (t) {
            //XXX: stateful und setState besser?
            weatherData.temperature = t;
            onChanged(weatherData);
          },
        ),
      ],
    );
  }
}

class TemperaturePreview extends StatelessWidget {
  final Function(int?) onChanged;
  final int? temperature;
  const TemperaturePreview(
      {required this.temperature, Key? key, required this.onChanged})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    //TODO: make it editable
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
  final Function(WeatherData) onChanged;
  const WindPreview(
      {required this.weatherData, Key? key, required this.onChanged})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        WindDirectionIcon(
          dir: weatherData.wind_direction,
          onChanged: (wd) {
            //XXX: stateful und setState besser?
            weatherData.wind_direction = wd;
            onChanged(weatherData);
          },
        ),
        WindSpeedIcon(
          windSpeed: weatherData.wind_speed,
          onChanged: (wp) {
            //XXX: stateful und setState besser?
            weatherData.wind_speed = wp;
            onChanged(weatherData);
          },
        )
      ],
    );
  }
}

class WindSpeedIcon extends StatelessWidget {
  final WindPower? windSpeed;
  final Function(WindPower?) onChanged;
  const WindSpeedIcon(
      {Key? key, required this.windSpeed, required this.onChanged})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DropDownBuilder<WindPower>(
        possibilities: [null, ...WindPower.values],
        builder: builder,
        selected: windSpeed,
        onChanged: onChanged);
    ;
  }

  Widget builder(WindPower? wp) => Text(windSpeed == WindPower.none
      ? "windstill"
      : windSpeed == WindPower.medium
          ? "mäßiger wind"
          : windSpeed == WindPower.strong
              ? "starker wind"
              : "unbekannter wind");
}

class WindDirectionIcon extends StatelessWidget {
  final WindDirection? dir;
  final Function(WindDirection?) onChanged;
  const WindDirectionIcon({
    Key? key,
    required this.dir,
    required this.onChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DropDownBuilder<WindDirection>(
        possibilities: [null, ...WindDirection.values],
        builder: (dir) => Icon(windDir2icon(dir)),
        selected: dir,
        onChanged: onChanged);
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
