import 'location_point.dart';

class TrackingSession {
  final String id;
  String name;
  final DateTime startTime;
  DateTime? endTime;
  final List<LocationPoint> points;
  final int tickRateMs;
  double totalDistanceMeters;
  int? pointCount; // From server list endpoint (when points aren't loaded)

  TrackingSession({
    required this.id,
    required this.name,
    required this.startTime,
    this.endTime,
    List<LocationPoint>? points,
    this.tickRateMs = 1000,
    this.totalDistanceMeters = 0.0,
    this.pointCount,
  }) : points = points ?? [];

  Duration get duration {
    final end = endTime ?? DateTime.now();
    return end.difference(startTime);
  }

  bool get isActive => endTime == null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime?.toIso8601String(),
        'tickRateMs': tickRateMs,
        'totalDistanceMeters': totalDistanceMeters,
        'points': points.map((p) => p.toJson()).toList(),
      };

  /// JSON without points (for list endpoints).
  Map<String, dynamic> toJsonSummary() => {
        'id': id,
        'name': name,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime?.toIso8601String(),
        'tickRateMs': tickRateMs,
        'totalDistanceMeters': totalDistanceMeters,
        'pointCount': points.length,
      };

  factory TrackingSession.fromJson(Map<String, dynamic> json) =>
      TrackingSession(
        id: json['id'] as String,
        name: json['name'] as String,
        startTime: DateTime.parse(json['startTime'] as String),
        endTime: json['endTime'] != null
            ? DateTime.parse(json['endTime'] as String)
            : null,
        tickRateMs: json['tickRateMs'] as int? ?? 1000,
        totalDistanceMeters:
            (json['totalDistanceMeters'] as num?)?.toDouble() ?? 0.0,
        pointCount: json['pointCount'] as int?,
        points: (json['points'] as List<dynamic>?)
                ?.map((p) =>
                    LocationPoint.fromJson(p as Map<String, dynamic>))
                .toList() ??
            [],
      );
}
