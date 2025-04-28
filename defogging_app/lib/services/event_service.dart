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

  // 添加事件发现监听器
  void addOnEventDiscoveredListener(Function(MapEvent) listener) {
    _onEventDiscovered.add(listener);
  }

  // 移除事件发现监听器
  void removeOnEventDiscoveredListener(Function(MapEvent) listener) {
    _onEventDiscovered.remove(listener);
  }

  // 加载保存的事件
  Future<void> loadEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final eventsJson = prefs.getStringList(_eventsKey) ?? [];
    _events.clear();
    _events.addAll(
      eventsJson.map((json) => MapEvent.fromJson(jsonDecode(json))),
    );
  }

  // 保存事件
  Future<void> saveEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final eventsJson = _events.map((event) => jsonEncode(event.toJson())).toList();
    await prefs.setStringList(_eventsKey, eventsJson);
  }

  // 生成随机事件
  MapEvent generateRandomEvent(LatLng position) {
    final eventTypes = EventType.values;
    final type = eventTypes[_random.nextInt(eventTypes.length)];
    
    String title;
    String description;
    String? reward;

    switch (type) {
      case EventType.treasure:
        title = '神秘宝藏';
        description = '你发现了一个神秘的宝藏！';
        reward = '获得100金币';
        break;
      case EventType.story:
        title = '神秘故事';
        description = '这里似乎有一个有趣的故事...';
        break;
      case EventType.challenge:
        title = '探索挑战';
        description = '完成这个挑战来获得奖励！';
        reward = '获得50经验值';
        break;
      case EventType.surprise:
        title = '意外惊喜';
        description = '哇！这是一个惊喜！';
        reward = '获得随机奖励';
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

  // 在指定区域内生成随机事件
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

  // 检查是否发现新事件
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

  // 计算两点之间的距离（米）
  double calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371000; // 地球半径（米）
    final double lat1 = point1.latitude * pi / 180;
    final double lat2 = point2.latitude * pi / 180;
    final double dLat = (point2.latitude - point1.latitude) * pi / 180;
    final double dLng = (point2.longitude - point1.longitude) * pi / 180;

    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLng / 2) * sin(dLng / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  // 获取所有事件
  List<MapEvent> getAllEvents() {
    return List.unmodifiable(_events);
  }

  // 获取未发现的事件
  List<MapEvent> getUndiscoveredEvents() {
    return _events.where((event) => !event.isDiscovered).toList();
  }

  // 获取已发现的事件
  List<MapEvent> getDiscoveredEvents() {
    return _events.where((event) => event.isDiscovered).toList();
  }

  // 清除所有事件
  Future<void> clearEvents() async {
    _events.clear();
    await saveEvents();
  }

  // 添加事件
  Future<void> addEvent(MapEvent event) async {
    _events.add(event);
    await saveEvents();
  }
} 