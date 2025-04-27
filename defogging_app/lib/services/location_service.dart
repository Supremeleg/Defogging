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
  
  // 定义坐标精度（米）
  static const double _coordinatePrecision = 10.0;
  
  // 添加位置更新回调
  Function(LocationPoint)? onLocationUpdated;
  
  // 上传位置到 Firestore
  Future<void> uploadLocationToFirestore(LocationPoint location) async {
    try {
      await FirebaseFirestore.instance.collection('locations').add({
        'latitude': location.latitude,
        'longitude': location.longitude,
        'visitCount': location.visitCount,
        'timestamp': location.timestamp.toIso8601String(),
      });
    } catch (e) {
      print('上传位置到 Firestore 失败: $e');
    }
  }
  
  // 添加获取当前位置的方法
  Future<LocationPoint?> getCurrentLocation() async {
    try {
      // 检查位置服务是否启用
      bool serviceEnabled = await _location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await _location.requestService();
        if (!serviceEnabled) return null;
      }

      // 检查位置权限
      PermissionStatus permission = await _location.hasPermission();
      if (permission == PermissionStatus.denied) {
        permission = await _location.requestPermission();
        if (permission != PermissionStatus.granted) return null;
      }

      // 获取当前位置
      final locationData = await _location.getLocation();
      if (locationData.latitude == null || locationData.longitude == null) return null;

      return LocationPoint(
        latitude: locationData.latitude!,
        longitude: locationData.longitude!,
        visitCount: 1,
        timestamp: DateTime.now(),
      );
    } catch (e) {
      print('获取当前位置失败: $e');
      return null;
    }
  }
  
  // 计算两点之间的距离（米）
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000; // 地球半径（米）
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
      // 检查位置服务是否启用
      bool serviceEnabled = await _location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await _location.requestService();
        if (!serviceEnabled) return;
      }

      // 检查位置权限
      PermissionStatus permission = await _location.hasPermission();
      if (permission == PermissionStatus.denied) {
        permission = await _location.requestPermission();
        if (permission != PermissionStatus.granted) return;
      }

      // 设置位置更新参数
      await _location.changeSettings(
        accuracy: LocationAccuracy.high,
        interval: 10000, // 每10秒更新一次
        distanceFilter: 10, // 移动10米才更新
      );

      // 尝试启用后台模式
      try {
        await _location.enableBackgroundMode(enable: true);
        print('后台位置模式已启用');
      } catch (e) {
        print('无法启用后台位置模式: $e');
        // 继续执行，但只在前台跟踪位置
      }

      // 开始监听位置变化
      _locationSubscription = _location.onLocationChanged.listen(
        (LocationData currentLocation) async {
          if (currentLocation.latitude == null || currentLocation.longitude == null) return;

          try {
            // 获取所有位置记录
            List<LocationPoint> allLocations = await _dbHelper.getAllLocations();
            
            // 查找最近的位置点
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
              // 更新访问次数
              nearestLocation = LocationPoint(
                id: nearestLocation.id,
                latitude: nearestLocation.latitude,
                longitude: nearestLocation.longitude,
                visitCount: nearestLocation.visitCount + 1,
                timestamp: DateTime.now(),
              );
              await _dbHelper.updateLocation(nearestLocation);
              print('更新位置点访问次数: ${nearestLocation.visitCount}');
              await uploadLocationToFirestore(nearestLocation);
              // 通知位置更新
              onLocationUpdated?.call(nearestLocation);
            } else {
              // 创建新的位置记录
              LocationPoint newLocation = LocationPoint(
                latitude: currentLocation.latitude!,
                longitude: currentLocation.longitude!,
                visitCount: 1,
                timestamp: DateTime.now(),
              );
              await _dbHelper.insertLocation(newLocation);
              print('新建位置点记录');
              await uploadLocationToFirestore(newLocation);
              // 通知位置更新
              onLocationUpdated?.call(newLocation);
            }
          } catch (e) {
            print('处理位置更新时出错: $e');
          }
        },
        onError: (e) {
          print('位置监听错误: $e');
          _isListening = false;
        },
        cancelOnError: false,
      );

      _isListening = true;
      print('位置跟踪服务已启动');
    } catch (e) {
      print('启动位置跟踪服务时出错: $e');
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
        print('后台位置模式已禁用');
      } catch (e) {
        print('禁用后台位置模式时出错: $e');
      }
      
      print('位置跟踪服务已停止');
    } catch (e) {
      print('停止位置跟踪服务时出错: $e');
      rethrow;
    }
  }

  Future<List<LocationPoint>> getAllLocations() async {
    try {
      return await _dbHelper.getAllLocations();
    } catch (e) {
      print('获取所有位置记录时出错: $e');
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