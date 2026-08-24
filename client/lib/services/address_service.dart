import 'package:dio/dio.dart';

/// A single address/place match from [AddressService.search].
class AddressResult {
  const AddressResult({
    required this.displayName,
    required this.latitude,
    required this.longitude,
  });

  final String displayName;
  final double latitude;
  final double longitude;
}

/// Address autocomplete backed by Photon (photon.komoot.io) — a free,
/// keyless geocoder built on OpenStreetMap data. Picked over Google Places
/// Autocomplete for the same reason as [WeatherService]: no API key or
/// billing account needed. It does prefix/token matching (so "Kazimier"
/// matches a street like "Doktora Kazimierza Jaczewskiego") and, given a
/// bias point, ranks nearby results higher — which is the only practical
/// way to disambiguate same-named streets that recur across many towns.
class AddressService {
  AddressService()
    : _dio = Dio(
        // Photon's public instance 403s requests carrying Dart's default
        // "Dart/x.x (dart:io)" User-Agent — a real-looking UA is required.
        BaseOptions(headers: {'User-Agent': 'CallendarApp/1.0'}),
      );

  final Dio _dio;

  Future<List<AddressResult>> search(
    String query, {
    double? biasLatitude,
    double? biasLongitude,
    int limit = 6,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    final response = await _dio.get<Map<String, dynamic>>(
      'https://photon.komoot.io/api/',
      queryParameters: {
        'q': trimmed,
        'limit': limit,
        // A soft ranking bias, not a hard filter — a query for an address
        // in a different city still matches, it just isn't boosted.
        if (biasLatitude != null && biasLongitude != null) 'lat': biasLatitude,
        if (biasLatitude != null && biasLongitude != null) 'lon': biasLongitude,
      },
    );
    final features = response.data?['features'] as List? ?? [];
    final results = features.map((raw) {
      final feature = raw as Map<String, dynamic>;
      final props = feature['properties'] as Map<String, dynamic>;
      final coords = (feature['geometry'] as Map<String, dynamic>)['coordinates'] as List;

      final street = props['street'] as String?;
      final houseNumber = props['housenumber'] as String?;
      // An address point (street + housenumber both present) reads as
      // "Street 12"; a street/place result falls back to its own name.
      final headline = street != null
          ? [street, houseNumber].whereType<String>().where((s) => s.isNotEmpty).join(' ')
          : props['name'] as String?;

      final parts = <String>[
        if (headline != null && headline.isNotEmpty) headline,
        if (props['city'] is String) props['city'] as String,
        if (props['country'] is String) props['country'] as String,
      ];
      final label = <String>[];
      for (final part in parts) {
        if (label.isEmpty || label.last != part) label.add(part);
      }

      return AddressResult(
        displayName: label.join(', '),
        latitude: (coords[1] as num).toDouble(),
        longitude: (coords[0] as num).toDouble(),
      );
    }).toList();

    // OSM often carries the same street+housenumber on several distinct
    // features at that address (e.g. a church and a monastery sharing one
    // building) — collapsing our headline to just street+number then makes
    // them indistinguishable, so drop the later duplicates.
    final seen = <String>{};
    return [
      for (final result in results)
        if (seen.add(result.displayName)) result,
    ];
  }
}
