class LocationPoint {
  final int? id;
  final double latitude;
  final double longitude;
  final int visitCount;
  final DateTime timestamp;

  LocationPoint({
    this.id,
    required this.latitude,
    required this.longitude,
    required this.visitCount,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'latitude': latitude,
      'longitude': longitude,
      'visit_count': visitCount,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory LocationPoint.fromMap(Map<String, dynamic> map) {
    return LocationPoint(
      id: map['id'],
      latitude: map['latitude'],
      longitude: map['longitude'],
      visitCount: map['visit_count'],
      timestamp: DateTime.parse(map['timestamp']),
    );
  }
} 