import 'dart:async';
import 'dart:math' as math;

import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  LocationBroadcastService
//  Writes the driver's GPS position to Firebase Realtime Database every 4s
//  while an active delivery is in progress.
//
//  RTDB path:  active_deliveries/{orderId}/driver_location
//    Fields: lat, lng, bearing, speed, timestamp
//
//  Usage:
//    final svc = LocationBroadcastService();
//    await svc.start(orderId: 'abc123', driverId: 'xyz');
//    ...
//    svc.stop();
// ─────────────────────────────────────────────────────────────────────────────

class LocationBroadcastService {
  static const _intervalSeconds = 4;

  final _rtdb = FirebaseDatabase.instance;

  Timer? _timer;
  StreamSubscription<Position>? _positionSub;
  Position? _lastPosition;
  String? _orderId;
  bool _running = false;

  bool get isRunning => _running;

  // ── Start broadcasting ────────────────────────────────────────────────────
  Future<void> start({required String orderId, required String driverId}) async {
    if (_running) return;
    _orderId = orderId;
    _running = true;

    // Check & request permission
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever) {
      _running = false;
      return;
    }

    // Listen to position stream for smooth bearing/speed
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5, // metres
      ),
    ).listen((pos) => _lastPosition = pos);

    // Write to RTDB on interval
    _timer = Timer.periodic(
      const Duration(seconds: _intervalSeconds),
      (_) => _write(driverId),
    );

    // Write immediately on start
    _write(driverId);
  }

  // ── Stop broadcasting ─────────────────────────────────────────────────────
  Future<void> stop() async {
    _running = false;
    _timer?.cancel();
    _timer = null;
    await _positionSub?.cancel();
    _positionSub = null;

    // Clear RTDB node so consumer app knows driver is offline
    if (_orderId != null) {
      await _rtdb
          .ref('active_deliveries/$_orderId/driver_location')
          .remove()
          .catchError((_) {});
    }
    _orderId = null;
    _lastPosition = null;
  }

  // ── Internal write ────────────────────────────────────────────────────────
  Future<void> _write(String driverId) async {
    if (!_running || _orderId == null) return;

    Position pos;
    try {
      if (_lastPosition != null) {
        pos = _lastPosition!;
      } else {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
          ),
        );
        _lastPosition = pos;
      }
    } catch (_) {
      return;
    }

    final bearing = _normalizeBearing(pos.heading);

    await _rtdb.ref('active_deliveries/$_orderId/driver_location').set({
      'lat': pos.latitude,
      'lng': pos.longitude,
      'bearing': bearing,
      'speed': pos.speed, // m/s
      'driverId': driverId,
      'timestamp': ServerValue.timestamp,
    }).catchError((_) {});
  }

  double _normalizeBearing(double heading) {
    // heading from geolocator can be -1 when not moving; default to 0
    if (heading < 0) return 0;
    return heading % 360;
  }

  // ── Dispose ───────────────────────────────────────────────────────────────
  void dispose() {
    stop();
  }
}
