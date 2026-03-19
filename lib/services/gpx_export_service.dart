import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:gpx/gpx.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/tracking_session.dart';

class GpxExportService {
  Future<String> exportSession(TrackingSession session) async {
    if (kIsWeb) {
      throw UnsupportedError('GPX export is not supported on web');
    }

    final gpx = Gpx();
    gpx.creator = 'Follow Me On Map';
    gpx.metadata = Metadata(
      name: session.name,
      time: session.startTime,
    );

    final track = Trk(
      name: session.name,
      trksegs: [
        Trkseg(
          trkpts: session.points.map((point) {
            return Wpt(
              lat: point.latitude,
              lon: point.longitude,
              ele: point.altitude,
              time: point.timestamp,
            );
          }).toList(),
        ),
      ],
    );

    gpx.trks = [track];

    final gpxString = GpxWriter().asString(gpx, pretty: true);

    final directory = await getApplicationDocumentsDirectory();
    final fileName =
        'session_${session.id.substring(0, 8)}_${session.startTime.millisecondsSinceEpoch}.gpx';
    final file = File('${directory.path}/$fileName');
    await file.writeAsString(gpxString);

    return file.path;
  }

  Future<void> shareSession(TrackingSession session) async {
    if (kIsWeb) {
      throw UnsupportedError('GPX sharing is not supported on web');
    }

    final filePath = await exportSession(session);
    await Share.shareXFiles(
      [XFile(filePath)],
      subject: 'GPS Track: ${session.name}',
    );
  }
}
