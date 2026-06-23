import 'dart:convert';
import 'package:http/http.dart' as http;

class PredictiveService {
  final String baseUrl;
  PredictiveService({this.baseUrl = 'http://localhost:8000'});

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

  /// Predict with optional contextual data. Any omitted fields are ignored.
    Future<double?> predictWithContext(List<double> features,
      {Map<String, dynamic>? weather,
      String? season,
      bool? isHoliday,
      double? trendScore,
      int? eventCount,
        double? latitude,
        double? longitude,
        bool fetchWeather = true,
        String? countryCode,
        List<Map<String, dynamic>>? salesHistory}) async {
    final url = Uri.parse('$baseUrl/predict');
    final body = {
      'features': features,
      if (weather != null) 'weather': weather,
      if (season != null) 'season': season,
      if (isHoliday != null) 'is_holiday': isHoliday,
      if (trendScore != null) 'trend_score': trendScore,
      if (eventCount != null) 'event_count': eventCount,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (fetchWeather) 'fetch_weather': true,
      if (countryCode != null) 'country_code': countryCode,
      if (salesHistory != null) 'sales_history': salesHistory,
    };

    final resp = await http.post(url,
        headers: {'Content-Type': 'application/json'}, body: jsonEncode(body));
    if (resp.statusCode == 200) {
      final map = jsonDecode(resp.body);
      return (map['prediction'] as num).toDouble();
    }
    return null;
  }

  /// Convenience method that auto-populates common contextual defaults and calls predictWithContext.
  Future<double?> predictAuto(List<double> features, {double? latitude, double? longitude, String? countryCode}) async {
    return predictWithContext(features, latitude: latitude, longitude: longitude, fetchWeather: true, countryCode: countryCode ?? 'KE');
  }
}
