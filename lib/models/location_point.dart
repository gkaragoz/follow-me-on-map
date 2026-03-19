import 'package:hive/hive.dart';

part 'location_point.g.dart';

@HiveType(typeId: 0)
class LocationPoint extends HiveObject {
  @HiveField(0)
  final double latitude;

  @HiveField(1)
  final double longitude;

  @HiveField(2)
  final double altitude;

  @HiveField(3)
  final double speed;

  @HiveField(4)
  final double accuracy;

  @HiveField(5)
  final DateTime timestamp;

  LocationPoint({
    required this.latitude,
    required this.longitude,
    required this.altitude,
    required this.speed,
    required this.accuracy,
    required this.timestamp,
  });
}
