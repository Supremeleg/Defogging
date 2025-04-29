import 'package:location/location.dart';
import '../database/database_helper.dart';
import '../database/location_model.dart';
import 'dart:math';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class LocationService {
  final Location _location = Location();
  final DatabaseHelper _dbHelper = DatabaseHelper();
  bool _isListening = false;
  StreamSubscription<LocationData>? _locationSubscription;
  
  // Define coordinate precision (meters)
  static const double _coordinatePrecision = 10.0;
  
  // Add location update callback
  Function(LocationPoint)? onLocationUpdated;
  
  // Upload location to Firestore
  Future<void> uploadLocationToFirestore(LocationPoint location) async {
    try {
      await FirebaseFirestore.instance.collection('locations').add({
        'latitude': location.latitude,
        'longitude': location.longitude,
        'visitCount': location.visitCount,
        'timestamp': location.timestamp.toIso8601String(),
      });
    } catch (e) {
      print('Failed to upload location to Firestore: $e');
    }
  }
  
  // Add method to get current location
  Future<LocationPoint?> getCurrentLocation() async {
    try {
      // Check if location service is enabled
      bool serviceEnabled = await _location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await _location.requestService();
        if (!serviceEnabled) return null;
      }

      // Check location permission
      PermissionStatus permission = await _location.hasPermission();
      if (permission == PermissionStatus.denied) {
        permission = await _location.requestPermission();
        if (permission != PermissionStatus.granted) return null;
      }

      // Get current location
      final locationData = await _location.getLocation();
      if (locationData.latitude == null || locationData.longitude == null) return null;

      return LocationPoint(
        latitude: locationData.latitude!,
        longitude: locationData.longitude!,
        visitCount: 1,
        timestamp: DateTime.now(),
      );
    } catch (e) {
      print('Failed to get current location: $e');
      return null;
    }
  }
  
  // Calculate distance between two points (meters)
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000; // Earth radius (meters)
    double dLat = _toRadians(lat2 - lat1);
    double dLon = _toRadians(lon2 - lon1);
    
    double a = sin(dLat/2) * sin(dLat/2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
        sin(dLon/2) * sin(dLon/2);
    
    double c = 2 * atan2(sqrt(a), sqrt(1-a));
    return earthRadius * c;
  }
  
  double _toRadians(double degree) {
    return degree * pi / 180;
  }

  Future<void> startLocationTracking() async {
    if (_isListening) return;

    try {
      // Check if location service is enabled
      bool serviceEnabled = await _location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await _location.requestService();
        if (!serviceEnabled) return;
      }

      // Check location permission
      PermissionStatus permission = await _location.hasPermission();
      if (permission == PermissionStatus.denied) {
        permission = await _location.requestPermission();
        if (permission != PermissionStatus.granted) return;
      }

      // Set location update parameters
      await _location.changeSettings(
        accuracy: LocationAccuracy.high,
        interval: 10000, // Update every 10 seconds
        distanceFilter: 10, // Update when moving 10 meters
      );

      // Try to enable background mode
      try {
        await _location.enableBackgroundMode(enable: true);
        print('Background location mode enabled');
      } catch (e) {
        print('Unable to enable background location mode: $e');
        // Continue execution, but only track location in foreground
      }

      // Start listening to location changes
      _locationSubscription = _location.onLocationChanged.listen(
        (LocationData currentLocation) async {
          if (currentLocation.latitude == null || currentLocation.longitude == null) return;

          try {
            // Get all location records
            List<LocationPoint> allLocations = await _dbHelper.getAllLocations();
            
            // Find nearest location point
            LocationPoint? nearestLocation;
            double minDistance = double.infinity;
            
            for (var location in allLocations) {
              double distance = _calculateDistance(
                currentLocation.latitude!,
                currentLocation.longitude!,
                location.latitude,
                location.longitude
              );
              
              if (distance < minDistance) {
                minDistance = distance;
                nearestLocation = location;
              }
            }

            if (nearestLocation != null && minDistance <= _coordinatePrecision) {
              // Update visit count
              nearestLocation = LocationPoint(
                id: nearestLocation.id,
                latitude: nearestLocation.latitude,
                longitude: nearestLocation.longitude,
                visitCount: nearestLocation.visitCount + 1,
                timestamp: DateTime.now(),
              );
              await _dbHelper.updateLocation(nearestLocation);
              print('Updated location point visit count: ${nearestLocation.visitCount}');
              await uploadLocationToFirestore(nearestLocation);
              // Notify location update
              onLocationUpdated?.call(nearestLocation);
            } else {
              // Create new location record
              LocationPoint newLocation = LocationPoint(
                latitude: currentLocation.latitude!,
                longitude: currentLocation.longitude!,
                visitCount: 1,
                timestamp: DateTime.now(),
              );
              await _dbHelper.insertLocation(newLocation);
              print('Created new location point record');
              await uploadLocationToFirestore(newLocation);
              // Notify location update
              onLocationUpdated?.call(newLocation);
            }
          } catch (e) {
            print('Error processing location update: $e');
          }
        },
        onError: (e) {
          print('Location listener error: $e');
          _isListening = false;
        },
        cancelOnError: false,
      );

      _isListening = true;
      print('Location tracking service started');
    } catch (e) {
      print('Error starting location tracking service: $e');
      _isListening = false;
      rethrow;
    }
  }

  Future<void> stopLocationTracking() async {
    try {
      await _locationSubscription?.cancel();
      _locationSubscription = null;
      _isListening = false;
      
      try {
        await _location.enableBackgroundMode(enable: false);
        print('Background location mode disabled');
      } catch (e) {
        print('Error disabling background location mode: $e');
      }
      
      print('Location tracking service stopped');
    } catch (e) {
      print('Error stopping location tracking service: $e');
      rethrow;
    }
  }

  Future<List<LocationPoint>> getAllLocations() async {
    try {
      return await _dbHelper.getAllLocations();
    } catch (e) {
      print('Error getting all location records: $e');
      rethrow;
    }
  }

  bool isTracking() {
    return _isListening;
  }

  Future<void> saveVirtualLocation(LatLng latLng) async {
    final location = LocationPoint(
      latitude: latLng.latitude,
      longitude: latLng.longitude,
      visitCount: 1,
      timestamp: DateTime.now(),
    );
    await _dbHelper.insertLocation(location);
  }
} 