import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/material.dart';

enum EventType {
  treasure,    // Treasure
  story,       // Story event
  challenge,   // Challenge
  surprise     // Surprise
}

class MapEvent {
  final String id;
  final String title;
  final String description;
  final EventType type;
  final LatLng position;
  final bool isDiscovered;
  final DateTime createdAt;
  final DateTime? discoveredAt;
  final String? reward;
  final double radius; // Trigger radius (meters)
  final double maxVisibleDistance; // Maximum visible distance (meters)
  final double minOpacity; // Minimum opacity
  final double maxOpacity; // Maximum opacity
  final double minSize; // Minimum size
  final double maxSize; // Maximum size

  MapEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.position,
    this.isDiscovered = false,
    required this.createdAt,
    this.discoveredAt,
    this.reward,
    this.radius = 50.0,
    this.maxVisibleDistance = 500.0,
    this.minOpacity = 0.6,
    this.maxOpacity = 1.0,
    this.minSize = 48.0,
    this.maxSize = 96.0,
  });

  // Get event icon
  IconData get icon {
    switch (type) {
      case EventType.treasure:
        return Icons.workspace_premium;
      case EventType.story:
        return Icons.menu_book;
      case EventType.challenge:
        return Icons.emoji_events;
      case EventType.surprise:
        return Icons.card_giftcard;
    }
  }

  // Get event color
  Color get color {
    switch (type) {
      case EventType.treasure:
        return Colors.amber;
      case EventType.story:
        return Colors.blue;
      case EventType.challenge:
        return Colors.purple;
      case EventType.surprise:
        return Colors.pink;
    }
  }

  // Calculate opacity based on current distance
  double calculateOpacity(double distance) {
    if (distance > maxVisibleDistance) return 0.0;
    if (distance <= radius) return maxOpacity;
    return minOpacity + (maxOpacity - minOpacity) * 
           (1 - (distance - radius) / (maxVisibleDistance - radius));
  }

  // Calculate size based on current distance
  double calculateSize(double distance) {
    if (distance > maxVisibleDistance) return 0.0;
    if (distance <= radius) return maxSize;
    return minSize + (maxSize - minSize) * 
           (1 - (distance - radius) / (maxVisibleDistance - radius));
  }

  // Create object from JSON
  factory MapEvent.fromJson(Map<String, dynamic> json) {
    return MapEvent(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      type: EventType.values.firstWhere(
        (e) => e.toString() == 'EventType.${json['type']}',
      ),
      position: LatLng(
        json['position']['latitude'],
        json['position']['longitude'],
      ),
      isDiscovered: json['isDiscovered'] ?? false,
      createdAt: DateTime.parse(json['createdAt']),
      discoveredAt: json['discoveredAt'] != null
          ? DateTime.parse(json['discoveredAt'])
          : null,
      reward: json['reward'],
      radius: json['radius'] ?? 20.0,
      maxVisibleDistance: json['maxVisibleDistance'] ?? 200.0,
      minOpacity: json['minOpacity'] ?? 0.4,
      maxOpacity: json['maxOpacity'] ?? 1.0,
      minSize: json['minSize'] ?? 32.0,
      maxSize: json['maxSize'] ?? 64.0,
    );
  }

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'type': type.toString().split('.').last,
      'position': {
        'latitude': position.latitude,
        'longitude': position.longitude,
      },
      'isDiscovered': isDiscovered,
      'createdAt': createdAt.toIso8601String(),
      'discoveredAt': discoveredAt?.toIso8601String(),
      'reward': reward,
      'radius': radius,
      'maxVisibleDistance': maxVisibleDistance,
      'minOpacity': minOpacity,
      'maxOpacity': maxOpacity,
      'minSize': minSize,
      'maxSize': maxSize,
    };
  }

  // Create a copy of the event with discovered status
  MapEvent copyWithDiscovered() {
    return MapEvent(
      id: id,
      title: title,
      description: description,
      type: type,
      position: position,
      isDiscovered: true,
      createdAt: createdAt,
      discoveredAt: DateTime.now(),
      reward: reward,
      radius: radius,
      maxVisibleDistance: maxVisibleDistance,
      minOpacity: minOpacity,
      maxOpacity: maxOpacity,
      minSize: minSize,
      maxSize: maxSize,
    );
  }
} 