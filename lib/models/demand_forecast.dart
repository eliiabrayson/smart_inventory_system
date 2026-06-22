class DemandForecast {
  final String id;
  final double predicted;

  DemandForecast({required this.id, required this.predicted});

  factory DemandForecast.fromMap(Map<String, dynamic> m) => DemandForecast(
        id: m['id']?.toString() ?? '',
        predicted: (m['predicted'] ?? 0).toDouble(),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'predicted': predicted,
      };
}
