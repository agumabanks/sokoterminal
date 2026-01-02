import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

class PlacesService {
  final Dio _dio = Dio();
  final String _apiKey = 'AIzaSyDTkxOUe2JxRQ18iNIIq5cGe76egsBs2WE';
  String? _sessionToken;

  PlacesService() {
    _refreshSessionToken();
  }

  void _refreshSessionToken() {
    _sessionToken = const Uuid().v4();
  }

  Future<List<PlacePrediction>> search(String query) async {
    if (query.isEmpty) return [];

    try {
      debugPrint('[Places] autocomplete: "$query"');
      final response = await _dio.get(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json',
        queryParameters: {
          'input': query,
          'key': _apiKey,
          'sessiontoken': _sessionToken,
          'components': 'country:ug', // Restrict to Uganda
          'types': 'establishment|geocode', // Broad search
        },
      );

      if (response.statusCode == 200) {
        final predictions = response.data['predictions'] as List;
        debugPrint('[Places] autocomplete response: ${predictions.length} results');
        return predictions.map((p) => PlacePrediction.fromJson(p)).toList();
      }
      debugPrint('[Places] autocomplete status: ${response.statusCode}');
    } catch (e) {
      debugPrint('[Places] autocomplete error: $e');
      // Fail silently
    }
    return [];
  }

  Future<PlaceDetails?> getDetails(String placeId) async {
    try {
      debugPrint('[Places] details: $placeId');
      final response = await _dio.get(
        'https://maps.googleapis.com/maps/api/place/details/json',
        queryParameters: {
          'place_id': placeId,
          'key': _apiKey,
          'sessiontoken': _sessionToken,
          'fields': 'geometry,name,formatted_address',
        },
      );

      if (response.statusCode == 200) {
        final result = response.data['result'];
        _refreshSessionToken(); // Consumed session
        debugPrint('[Places] details response: OK');
        return PlaceDetails.fromJson(result);
      }
      debugPrint('[Places] details status: ${response.statusCode}');
    } catch (e) {
      debugPrint('[Places] details error: $e');
      // Fail silently
    }
    return null;
  }

  String staticMapUrl({
    required double lat,
    required double lng,
    int zoom = 16,
    int size = 900,
  }) {
    final clampedZoom = zoom.clamp(1, 20);
    final clampedSize = size.clamp(200, 1280);
    return 'https://maps.googleapis.com/maps/api/staticmap'
        '?center=$lat,$lng'
        '&zoom=$clampedZoom'
        '&size=${clampedSize}x${clampedSize}'
        '&maptype=roadmap'
        '&markers=color:0x6C63FF|$lat,$lng'
        '&key=$_apiKey';
  }
}

class PlacePrediction {
  final String placeId;
  final String description;
  final String mainText;
  final String secondaryText;

  PlacePrediction({
    required this.placeId,
    required this.description,
    required this.mainText,
    required this.secondaryText,
  });

  factory PlacePrediction.fromJson(Map<String, dynamic> json) {
    final struct = json['structured_formatting'] ?? {};
    return PlacePrediction(
      placeId: json['place_id'] ?? '',
      description: json['description'] ?? '',
      mainText: struct['main_text'] ?? '',
      secondaryText: struct['secondary_text'] ?? '',
    );
  }
}

class PlaceDetails {
  final String name;
  final String address;
  final double lat;
  final double lng;

  PlaceDetails({
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
  });

  factory PlaceDetails.fromJson(Map<String, dynamic> json) {
    final geo = json['geometry']?['location'] ?? {};
    return PlaceDetails(
      name: json['name'] ?? '',
      address: json['formatted_address'] ?? '',
      lat: (geo['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (geo['lng'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
