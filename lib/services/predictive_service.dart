import 'dart:convert';
import 'package:http/http.dart' as http;

class PredictiveService {
  final String baseUrl;
  PredictiveService({this.baseUrl = 'http://127.0.0.1:8000'});

  Future<double?> predict(List<double> features) async {
    final url = Uri.parse('$baseUrl/predict');
    final resp = await http.post(url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'features': features}));
    if (resp.statusCode == 200) {
      final map = jsonDecode(resp.body);
      return (map['prediction'] as num).toDouble();
    }
    return null;
  }

  /// Predict with contextual factors: weather, calendar event, lead time, market trend.
  Future<double?> predictWithContext(
    List<double> features, {
    Map<String, dynamic>? weather,
    int? calendarEvent,
    double? leadTime,
    double? marketTrend,
    double? latitude,
    double? longitude,
    bool fetchWeather = true,
  }) async {
    final url = Uri.parse('$baseUrl/predict');
    final body = {
      'features': features,
      if (weather != null) 'weather': weather,
      if (calendarEvent != null) 'calendar_event': calendarEvent,
      if (leadTime != null) 'lead_time': leadTime,
      if (marketTrend != null) 'market_trend': marketTrend,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (fetchWeather) 'fetch_weather': true,
    };

    final resp = await http.post(url,
        headers: {'Content-Type': 'application/json'}, body: jsonEncode(body));
    if (resp.statusCode == 200) {
      final map = jsonDecode(resp.body);
      return (map['prediction'] as num).toDouble();
    }
    return null;
  }

  Future<double?> predictAuto(List<double> features, {double? latitude, double? longitude}) async {
    return predictWithContext(
      features,
      latitude: latitude ?? -1.2921,
      longitude: longitude ?? 36.8219,
      fetchWeather: true,
    );
  }
}
