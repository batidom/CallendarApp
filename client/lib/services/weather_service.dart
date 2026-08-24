import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

/// A candidate result from a city-name search, for the settings screen's
/// "set your city" picker to disambiguate between same-named places.
class WeatherCityResult {
  const WeatherCityResult({
    required this.displayName,
    required this.latitude,
    required this.longitude,
  });

  final String displayName;
  final double latitude;
  final double longitude;
}

/// One day's forecast, keyed by local calendar date (time-of-day stripped)
/// in the [WeatherService.fetchForecast] result map.
class DailyWeather {
  const DailyWeather({
    required this.weatherCode,
    required this.maxTempC,
    required this.minTempC,
  });

  // WMO weather interpretation code — see WeatherCodeDisplay below.
  final int weatherCode;
  final double maxTempC;
  final double minTempC;
}

/// Talks to Open-Meteo (open-meteo.com) for city geocoding and daily
/// forecasts — free and keyless, which is why it was picked over a
/// commercial weather API for a self-hosted hobby app. Uses its own [Dio]
/// instance rather than [apiClientProvider]'s: this hits a public
/// third-party host, not our own backend, so it needs neither the base URL
/// nor the auth interceptor that one carries.
class WeatherService {
  WeatherService() : _dio = Dio();

  final Dio _dio;

  Future<List<WeatherCityResult>> searchCity(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    final response = await _dio.get<Map<String, dynamic>>(
      'https://geocoding-api.open-meteo.com/v1/search',
      queryParameters: {'name': trimmed, 'count': 8, 'language': 'en'},
    );
    final results = response.data?['results'] as List? ?? [];
    return results.map((raw) {
      final r = raw as Map<String, dynamic>;
      final parts = [r['name'], r['admin1'], r['country']]
          .whereType<String>()
          .where((s) => s.isNotEmpty)
          .toList();
      // Dedupe consecutive identical parts (e.g. a city whose admin1 name
      // matches its own name) without disturbing overall ordering.
      final label = <String>[];
      for (final part in parts) {
        if (label.isEmpty || label.last != part) label.add(part);
      }
      return WeatherCityResult(
        displayName: label.join(', '),
        latitude: (r['latitude'] as num).toDouble(),
        longitude: (r['longitude'] as num).toDouble(),
      );
    }).toList();
  }

  /// Keyed by local calendar date at midnight. Open-Meteo's free tier
  /// covers 16 days out, which comfortably spans the day-agenda view this
  /// feeds.
  Future<Map<DateTime, DailyWeather>> fetchForecast({
    required double latitude,
    required double longitude,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      'https://api.open-meteo.com/v1/forecast',
      queryParameters: {
        'latitude': latitude,
        'longitude': longitude,
        'daily': 'weathercode,temperature_2m_max,temperature_2m_min',
        'timezone': 'auto',
        'forecast_days': 16,
      },
    );
    final daily = response.data?['daily'] as Map<String, dynamic>?;
    if (daily == null) return {};

    final dates = (daily['time'] as List).cast<String>();
    final codes = (daily['weathercode'] as List).cast<num>();
    final maxTemps = (daily['temperature_2m_max'] as List).cast<num>();
    final minTemps = (daily['temperature_2m_min'] as List).cast<num>();

    final result = <DateTime, DailyWeather>{};
    for (var i = 0; i < dates.length; i++) {
      final date = DateTime.parse(dates[i]);
      result[DateTime(date.year, date.month, date.day)] = DailyWeather(
        weatherCode: codes[i].toInt(),
        maxTempC: maxTemps[i].toDouble(),
        minTempC: minTemps[i].toDouble(),
      );
    }
    return result;
  }
}

/// Maps Open-Meteo's WMO weather codes to a representative Material icon.
/// See https://open-meteo.com/en/docs for the full code table.
extension WeatherCodeDisplay on int {
  IconData get weatherIcon {
    if (this == 0) return Icons.wb_sunny_outlined;
    if (this <= 2) return Icons.wb_cloudy_outlined;
    if (this == 3) return Icons.cloud_outlined;
    if (this == 45 || this == 48) return Icons.foggy;
    if (this >= 51 && this <= 67) return Icons.water_drop_outlined;
    if (this >= 71 && this <= 77) return Icons.ac_unit;
    if (this >= 80 && this <= 82) return Icons.water_drop;
    if (this >= 85 && this <= 86) return Icons.snowing;
    if (this >= 95) return Icons.thunderstorm_outlined;
    return Icons.wb_cloudy_outlined;
  }
}
