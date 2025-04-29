import 'dart:math';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/event_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class EventService {
  static const String _eventsKey = 'map_events';
  final Random _random = Random();
  final List<MapEvent> _events = [];
  final List<Function(MapEvent)> _onEventDiscovered = [];

  // Add event discovery listener
  void addOnEventDiscoveredListener(Function(MapEvent) listener) {
    _onEventDiscovered.add(listener);
  }

  // Remove event discovery listener
  void removeOnEventDiscoveredListener(Function(MapEvent) listener) {
    _onEventDiscovered.remove(listener);
  }

  // Load saved events
  Future<void> loadEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final eventsJson = prefs.getStringList(_eventsKey) ?? [];
    _events.clear();
    _events.addAll(
      eventsJson.map((json) => MapEvent.fromJson(jsonDecode(json))),
    );
  }

  // Save events
  Future<void> saveEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final eventsJson = _events.map((event) => jsonEncode(event.toJson())).toList();
    await prefs.setStringList(_eventsKey, eventsJson);
  }

  // Generate random event
  MapEvent generateRandomEvent(LatLng position) {
    final eventTypes = EventType.values;
    final type = eventTypes[_random.nextInt(eventTypes.length)];
    
    String title;
    String description;
    String? reward;

    switch (type) {
      case EventType.treasure:
        title = 'Mysterious Treasure';
        description = 'You found a mysterious treasure!';
        reward = 'Get 100 gold coins';
        break;
      case EventType.story:
        title = 'Mysterious Story';
        description = 'There seems to be an interesting story here...';
        break;
      case EventType.challenge:
        title = 'Exploration Challenge';
        description = 'Complete this challenge to get rewards!';
        reward = 'Get 50 experience points';
        break;
      case EventType.surprise:
        title = 'Unexpected Surprise';
        description = 'Wow! This is a surprise!';
        reward = 'Get random rewards';
        break;
    }

    return MapEvent(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      description: description,
      type: type,
      position: position,
      createdAt: DateTime.now(),
      reward: reward,
    );
  }

  // Generate random events in specified area
  Future<void> generateEventsInArea(LatLngBounds bounds, int count) async {
    for (int i = 0; i < count; i++) {
      final lat = bounds.southwest.latitude +
          _random.nextDouble() * (bounds.northeast.latitude - bounds.southwest.latitude);
      final lng = bounds.southwest.longitude +
          _random.nextDouble() * (bounds.northeast.longitude - bounds.southwest.longitude);
      
      final event = generateRandomEvent(LatLng(lat, lng));
      _events.add(event);
    }
    await saveEvents();
  }

  // Check for new event discovery
  void checkForEvents(LatLng position) {
    for (var event in _events) {
      if (!event.isDiscovered) {
        final distance = calculateDistance(position, event.position);
        if (distance <= event.radius) {
          final discoveredEvent = event.copyWithDiscovered();
          _events[_events.indexOf(event)] = discoveredEvent;
          saveEvents();
          for (var listener in _onEventDiscovered) {
            listener(discoveredEvent);
          }
        }
      }
    }
  }

  // Calculate distance between two points (meters)
  double calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371000; // Earth radius (meters)
    final double lat1 = point1.latitude * pi / 180;
    final double lat2 = point2.latitude * pi / 180;
    final double dLat = (point2.latitude - point1.latitude) * pi / 180;
    final double dLng = (point2.longitude - point1.longitude) * pi / 180;

    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLng / 2) * sin(dLng / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  // Get all events
  List<MapEvent> getAllEvents() {
    return List.unmodifiable(_events);
  }

  // Get undiscovered events
  List<MapEvent> getUndiscoveredEvents() {
    return _events.where((event) => !event.isDiscovered).toList();
  }

  // Get discovered events
  List<MapEvent> getDiscoveredEvents() {
    return _events.where((event) => event.isDiscovered).toList();
  }

  // Clear all events
  Future<void> clearEvents() async {
    _events.clear();
    await saveEvents();
  }

  // Add event
  Future<void> addEvent(MapEvent event) async {
    _events.add(event);
    await saveEvents();
  }
} 