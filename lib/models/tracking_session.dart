import 'package:hive/hive.dart';
import 'location_point.dart';

part 'tracking_session.g.dart';

@HiveType(typeId: 1)
class TrackingSession extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  final DateTime startTime;

  @HiveField(3)
  DateTime? endTime;

  @HiveField(4)
  final List<LocationPoint> points;

  @HiveField(5)
  final int tickRateMs;

  @HiveField(6)
  double totalDistanceMeters;

  TrackingSession({
    required this.id,
    required this.name,
    required this.startTime,
    this.endTime,
    List<LocationPoint>? points,
    required this.tickRateMs,
    this.totalDistanceMeters = 0.0,
  }) : points = points ?? [];

  Duration get duration {
    final end = endTime ?? DateTime.now();
    return end.difference(startTime);
  }

  bool get isActive => endTime == null;
}
