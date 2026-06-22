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
}
