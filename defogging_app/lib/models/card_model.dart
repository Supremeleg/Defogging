import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class CardModel {
  final String id;
  final String title;
  final String description;
  final String type;
  final IconData icon;
  final Color color;
  final LatLng position;

  CardModel({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.icon,
    required this.color,
    required this.position,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'type': type,
      'icon': icon.codePoint,
      'color': color.value,
      'position': {
        'latitude': position.latitude,
        'longitude': position.longitude,
      },
    };
  }

  factory CardModel.fromJson(Map<String, dynamic> json) {
    return CardModel(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      type: json['type'],
      icon: IconData(json['icon'], fontFamily: 'MaterialIcons'),
      color: Color(json['color']),
      position: LatLng(
        json['position']['latitude'],
        json['position']['longitude'],
      ),
    );
  }
} 