import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/api_handler.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  Timer? _timer;
  bool _isTracking = false;

  Future<void> startTracking() async {
    if (_isTracking) return;
    
    // Check permissions
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint("Location services disabled.");
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint("Location permissions denied.");
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint("Location permissions denied forever.");
      return;
    }

    _isTracking = true;
    _pingLocation(); // initial ping
    _timer = Timer.periodic(const Duration(seconds: 15), (timer) {
      _pingLocation();
    });
    debugPrint("Location tracking started.");
  }

  void stopTracking() {
    _timer?.cancel();
    _isTracking = false;
    debugPrint("Location tracking stopped.");
  }

  Future<void> _pingLocation() async {
    if (!_isTracking) return;
    
    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      final prefs = await SharedPreferences.getInstance();
      int riderId = prefs.getInt('userId') ?? 0;
      
      if (riderId > 0) {
        final body = {
          'rider_id': riderId,
          'lat': position.latitude,
          'lng': position.longitude,
        };
        
        final response = await ApiHandler.postJson('update_live_location.php', body);
        debugPrint("Location update: $response");
      }
    } catch (e) {
      debugPrint("Error updating location: $e");
    }
  }
}
