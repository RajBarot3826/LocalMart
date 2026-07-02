import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_database/firebase_database.dart';
import '../utils/api_handler.dart';
import '../theme/app_theme.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  Timer? _timer;
  bool _isTracking = false;
  Position? _lastPosition;

  /// Get last known GPS position (used by map widgets to show rider marker)
  Position? get lastPosition => _lastPosition;

  /// Stream controller for live position updates that widgets can listen to
  final StreamController<Position> _positionController = StreamController<Position>.broadcast();
  Stream<Position> get positionStream => _positionController.stream;

  /// Request location permissions with a user dialog if denied
  Future<bool> requestPermissionWithPrompt(BuildContext context) async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enable GPS/Location services on your device.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      // Explain why we need location before requesting
      if (context.mounted) {
        final bool? proceed = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text("Location Access Required"),
            content: const Text(
              "LocalMart needs your location to track deliveries in real time, show your active position on the map, and coordinate deliveries with customers.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text("CANCEL"),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
                child: const Text("ALLOW"),
              ),
            ],
          ),
        );
        if (proceed != true) return false;
      }
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permission denied. Cannot start tracking.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text("Location Permission Blocked"),
            content: const Text(
              "Location permission has been permanently denied. Please enable it in the App Settings to track deliveries.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("CANCEL"),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Geolocator.openAppSettings();
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
                child: const Text("OPEN SETTINGS"),
              ),
            ],
          ),
        );
      }
      return false;
    }

    return permission == LocationPermission.always || permission == LocationPermission.whileInUse;
  }

  StreamSubscription<Position>? _positionSubscription;

  Future<void> startTracking({bool forceRequest = true}) async {
    // If already tracking, re-emit last known position
    if (_isTracking) {
      if (_lastPosition != null && !_positionController.isClosed) {
        _positionController.add(_lastPosition!);
      } else {
        _pingLocation();
      }
      return;
    }
    
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint("📍 GPS location services disabled on device.");
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied && forceRequest) {
      debugPrint("📍 Location permission denied. Requesting native OS permission dialog...");
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      debugPrint("📍 Location permission permanently denied or refused.");
      return;
    }

    _isTracking = true;
    _pingLocation(); // initial ping

    // 1. Set up high-frequency active position stream
    _positionSubscription?.cancel();
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5, // update every 5 meters
      ),
    ).listen((Position position) {
      _handleNewPosition(position);
    }, onError: (e) {
      debugPrint("❌ Error in position stream: $e");
    });

    // 2. Periodic backup timer (every 5s)
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _pingLocation();
    });
    debugPrint("📍 Location tracking activated (Live Stream + 5s backup timer).");
  }

  void stopTracking() {
    _timer?.cancel();
    _positionSubscription?.cancel();
    _isTracking = false;
    debugPrint("📍 Location tracking stopped.");
  }

  void _handleNewPosition(Position position) async {
    _lastPosition = position;
    if (!_positionController.isClosed) {
      _positionController.add(position);
    }

    final prefs = await SharedPreferences.getInstance();
    int riderId = prefs.getInt('userId') ?? 0;
    if (riderId > 0) {
      // 1. Update legacy MySQL database (as backup)
      ApiHandler.post('update_live_location.php', {
        'rider_id': riderId.toString(),
        'lat': position.latitude.toString(),
        'lng': position.longitude.toString(),
      }).then((response) {
        debugPrint("📍 Live location synced to MySQL: (${position.latitude}, ${position.longitude}) → $response");
      }).catchError((e) {
        debugPrint("⚠️ MySQL location sync error: $e");
      });

      // 2. Update Firebase Realtime Database (for instant smooth tracking)
      try {
        await FirebaseDatabase.instance.ref().child('riders').child('rider_$riderId').set({
          'lat': position.latitude,
          'lng': position.longitude,
          'updated_at': ServerValue.timestamp,
        });
        debugPrint("🔥 Live location written to Firebase RTDB for rider_$riderId");
      } catch (e) {
        debugPrint("⚠️ Failed to write location to Firebase RTDB: $e");
      }
    }
  }

  Future<void> _pingLocation() async {
    if (!_isTracking) return;
    try {
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
          ),
        ).timeout(const Duration(seconds: 4));
      } on TimeoutException {
        // GPS timed out — try last known position as fallback
        position = await Geolocator.getLastKnownPosition();
        debugPrint("📍 GPS timed out, using last known position: $position");
      }

      // Only update if we have a real position — never use hardcoded coordinates
      if (position != null && position.latitude != 0 && position.longitude != 0) {
        _handleNewPosition(position);
      } else {
        debugPrint("📍 No valid GPS position available, skipping update.");
      }
    } catch (e) {
      debugPrint("❌ Error in _pingLocation: $e");
    }
  }
}
