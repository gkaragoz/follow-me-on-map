// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tracking_session.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TrackingSessionAdapter extends TypeAdapter<TrackingSession> {
  @override
  final int typeId = 1;

  @override
  TrackingSession read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TrackingSession(
      id: fields[0] as String,
      name: fields[1] as String,
      startTime: fields[2] as DateTime,
      endTime: fields[3] as DateTime?,
      points: (fields[4] as List).cast<LocationPoint>(),
      tickRateMs: fields[5] as int,
      totalDistanceMeters: fields[6] as double,
    );
  }

  @override
  void write(BinaryWriter writer, TrackingSession obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.startTime)
      ..writeByte(3)
      ..write(obj.endTime)
      ..writeByte(4)
      ..write(obj.points)
      ..writeByte(5)
      ..write(obj.tickRateMs)
      ..writeByte(6)
      ..write(obj.totalDistanceMeters);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrackingSessionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
