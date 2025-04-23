import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_google_maps_webservices/places.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'dart:math';
import '../services/location_service.dart';
import '../database/location_model.dart';
import 'package:flutter/rendering.dart';

class GoogleMapPage extends StatefulWidget {
  const GoogleMapPage({super.key});

  @override
  State<GoogleMapPage> createState() => _GoogleMapPageState();
}

class _GoogleMapPageState extends State<GoogleMapPage> with AutomaticKeepAliveClientMixin {
  GoogleMapController? _mapController;
  final LatLng _center = const LatLng(51.5074, -0.1278); // 伦敦坐标
  Set<Circle> _circles = {};
  Set<Marker> _markers = {};
  final TextEditingController _searchController = TextEditingController();
  late final GoogleMapsPlaces _placesService;
  LatLng _currentPosition = const LatLng(51.5074, -0.1278); // 当前位置
  final LocationService _locationService = LocationService();
  bool _isTracking = false;

  // 添加熟悉度状态
  bool _isFamiliarityMode = true; // 默认开启熟悉度显示模式
  double _familiarityPercentage = 75.0; // 默认熟悉度为75%
  
  // 获取遮罩不透明度
  double get _overlayOpacity {
    // 这里后期可以根据传入的数据来设置不透明度
    return 0.5; // 暂时设置为50%
  }

  // 添加地图样式字符串
  final String _mapStyle = '''
  [
    {
      "featureType": "landscape",
      "elementType": "geometry",
      "stylers": [
        {
          "color": "#e0e0e0"
        }
      ]
    },
    {
      "featureType": "road",
      "elementType": "geometry",
      "stylers": [
        {
          "color": "#f5f5f5"
        }
      ]
    },
    {
      "featureType": "road.arterial",
      "elementType": "labels.text.fill",
      "stylers": [
        {
          "color": "#757575"
        }
      ]
    },
    {
      "featureType": "road.highway",
      "elementType": "geometry",
      "stylers": [
        {
          "color": "#dadada"
        }
      ]
    },
    {
      "featureType": "water",
      "elementType": "geometry",
      "stylers": [
        {
          "color": "#c9c9c9"
        }
      ]
    }
  ]
  ''';

  // 计算经纬度偏移
  LatLng _calculateOffset(LatLng position, double distanceMeters, String direction) {
    // 地球半径（米）
    const double earthRadius = 6371000;
    
    // 将距离转换为弧度
    double distanceRadians = distanceMeters / earthRadius;
    
    // 当前位置的经纬度（弧度）
    double latRad = position.latitude * (pi / 180);
    double lngRad = position.longitude * (pi / 180);
    
    double newLatRad, newLngRad;
    
    switch (direction) {
      case 'north':
        newLatRad = latRad + distanceRadians;
        newLngRad = lngRad;
        break;
      case 'south':
        newLatRad = latRad - distanceRadians;
        newLngRad = lngRad;
        break;
      case 'east':
        newLatRad = latRad;
        newLngRad = lngRad + distanceRadians / cos(latRad);
        break;
      case 'west':
        newLatRad = latRad;
        newLngRad = lngRad - distanceRadians / cos(latRad);
        break;
      default:
        return position;
    }
    
    // 转换回角度
    return LatLng(
      newLatRad * (180 / pi),
      newLngRad * (180 / pi),
    );
  }

  // 移动位置
  void _movePosition(String direction) {
    setState(() {
      _currentPosition = _calculateOffset(_currentPosition, 2.0, direction);
      
      // 清除现有标记
      _markers.clear();
      
      // 添加新的标记
      _markers.add(
        Marker(
          markerId: const MarkerId('current_position'),
          position: _currentPosition,
          infoWindow: InfoWindow(
            title: '当前位置',
            snippet: '纬度: ${_currentPosition.latitude}, 经度: ${_currentPosition.longitude}',
          ),
        ),
      );
      
      // 只在位置记录开启时添加白色圆点
      if (_isTracking) {
        _circles.add(
          Circle(
            circleId: CircleId(DateTime.now().toString()),
            center: _currentPosition,
            radius: 5, // 5米半径
            fillColor: Colors.white.withOpacity(0.7),
            strokeColor: Colors.white,
            strokeWidth: 1,
          ),
        );
      }
      
      _mapController?.animateCamera(
        CameraUpdate.newLatLng(_currentPosition),
      );
    });
  }

  @override
  bool get wantKeepAlive => true; // 保持页面状态

  @override
  void initState() {
    super.initState();
    _placesService = GoogleMapsPlaces(apiKey: dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '');
    _loadLocations();
    
    // 设置位置更新回调
    _locationService.onLocationUpdated = _onLocationUpdated;
    
    // 默认开启位置跟踪
    _isTracking = true;
    _locationService.startLocationTracking();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadLocations(); // 在依赖变化时重新加载
  }

  void _onLocationUpdated(LocationPoint location) {
    setState(() {
      // 添加位置点圆圈
      _circles.add(
        Circle(
          circleId: CircleId(DateTime.now().toString()),
          center: LatLng(location.latitude, location.longitude),
          radius: 5, // 5米半径
          fillColor: Colors.white.withOpacity(0.7),
          strokeColor: Colors.white,
          strokeWidth: 1,
        ),
      );
      
      // 更新或添加标记
      final markerId = MarkerId(location.id?.toString() ?? DateTime.now().toString());
      _markers.removeWhere((marker) => marker.markerId == markerId);
      _markers.add(
        Marker(
          markerId: markerId,
          position: LatLng(location.latitude, location.longitude),
          infoWindow: InfoWindow(
            title: '访问次数: ${location.visitCount}',
            snippet: '最后访问: ${location.timestamp.toString()}',
          ),
        ),
      );
    });
  }

  Future<void> _loadLocations() async {
    try {
      final locations = await _locationService.getAllLocations();
      if (!mounted) return;
      
      setState(() {
        // 保留当前位置标记
        final currentPositionMarker = _markers.where((m) => m.markerId == const MarkerId('current_position')).toList();
        
        // 清除现有标记和圆圈，但保留当前位置标记
        _markers.clear();
        _circles.clear();
        
        // 恢复当前位置标记
        if (currentPositionMarker.isNotEmpty) {
          _markers.add(currentPositionMarker.first);
        }
        
        // 添加所有位置点
        for (var location in locations) {
          // 添加圆圈
          _circles.add(
            Circle(
              circleId: CircleId(location.id.toString()),
              center: LatLng(location.latitude, location.longitude),
              radius: 5,
              fillColor: Colors.white.withOpacity(0.7),
              strokeColor: Colors.white,
              strokeWidth: 1,
            ),
          );
          
          // 添加标记
          _markers.add(
            Marker(
              markerId: MarkerId(location.id.toString()),
              position: LatLng(location.latitude, location.longitude),
              infoWindow: InfoWindow(
                title: '访问次数: ${location.visitCount}',
                snippet: '最后访问: ${location.timestamp.toString()}',
              ),
            ),
          );
        }
      });
    } catch (e) {
      print('加载位置点时出错: $e');
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _addMarker(_currentPosition);
    if (_isFamiliarityMode) {
      controller.setMapStyle(_mapStyle);
    }
  }

  void _addMarker(LatLng position) {
    setState(() {
      _markers.clear();
      _markers.add(
        Marker(
          markerId: const MarkerId('current_position'),
          position: position,
          infoWindow: InfoWindow(
            title: '当前位置',
            snippet: '纬度: ${position.latitude}, 经度: ${position.longitude}',
          ),
        ),
      );
      
      // 只在位置记录开启时添加白色圆点
      if (_isTracking) {
        _circles.add(
          Circle(
            circleId: CircleId(DateTime.now().toString()),
            center: position,
            radius: 5, // 5米半径
            fillColor: Colors.white.withOpacity(0.7),
            strokeColor: Colors.white,
            strokeWidth: 1,
          ),
        );
      }
    });
  }

  Future<void> _searchPlaces(String query) async {
    if (query.isEmpty) return;

    try {
      final predictions = await _placesService.autocomplete(
        query,
        location: Location(lat: _center.latitude, lng: _center.longitude),
        radius: 10000,
      );

      if (predictions.predictions.isNotEmpty) {
        final place = await _placesService.getDetailsByPlaceId(predictions.predictions[0].placeId!);
        final location = place.result.geometry!.location;
        final newPosition = LatLng(location.lat, location.lng);

        setState(() {
          _addMarker(newPosition);
        });

        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(newPosition, 15),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('搜索出错: $e');
      }
    }
  }

  void _toggleTracking() async {
    if (_isTracking) {
      await _locationService.stopLocationTracking();
    } else {
      await _locationService.startLocationTracking();
    }
    setState(() {
      _isTracking = !_isTracking;
    });
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // 需要调用super.build
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(
              target: _center,
              zoom: 15.0,
            ),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapType: MapType.normal,
            markers: _markers,
            circles: _circles,  // 添加圆圈集合
          ),
          // 添加熟悉度遮罩层
          if (_isFamiliarityMode)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  color: Colors.black.withOpacity(_overlayOpacity),
                ),
              ),
            ),
          Positioned(
            top: 60,
            left: 15,
            right: 15,
            child: Row(
              children: [
                if (_isFamiliarityMode)
                  Container(
                    width: 65,
                    height: 65,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        // 内层发光效果
                        BoxShadow(
                          color: Colors.white.withAlpha(204),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                        // 中层发光效果
                        BoxShadow(
                          color: Colors.white.withAlpha(128),
                          blurRadius: 8,
                          spreadRadius: 0,
                        ),
                        // 外层阴影
                        BoxShadow(
                          color: Colors.black.withAlpha(26),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        '${_familiarityPercentage.toInt()}%',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(26),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: '搜索地点...',
                        border: InputBorder.none,
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.search),
                          onPressed: () => _searchPlaces(_searchController.text),
                        ),
                      ),
                      onSubmitted: _searchPlaces,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 添加熟悉度切换按钮
          Positioned(
            bottom: 180, // 定位按钮上方
            right: 20,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(26),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                  if (_isFamiliarityMode)
                    BoxShadow(
                      color: Colors.white.withAlpha(204),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  if (_isFamiliarityMode)
                    BoxShadow(
                      color: Colors.white.withAlpha(128),
                      blurRadius: 8,
                      spreadRadius: 0,
                    ),
                ],
              ),
              child: Column(
                children: [
                  // 位置跟踪开关
                  IconButton(
                    icon: Icon(
                      _isTracking ? Icons.location_on : Icons.location_off,
                      color: _isTracking ? Colors.blue : Colors.grey,
                    ),
                    onPressed: _toggleTracking,
                    tooltip: _isTracking ? '停止位置跟踪' : '开始位置跟踪',
                  ),
                  // 熟悉度显示开关
                  IconButton(
                    icon: Icon(
                      _isFamiliarityMode ? Icons.visibility : Icons.visibility_off,
                      color: _isFamiliarityMode ? Colors.black : Colors.grey,
                    ),
                    onPressed: () {
                      setState(() {
                        _isFamiliarityMode = !_isFamiliarityMode;
                        // 切换遮罩模式时更新地图样式
                        if (_isFamiliarityMode) {
                          _mapController?.setMapStyle(_mapStyle);
                        } else {
                          _mapController?.setMapStyle(null); // 恢复默认样式
                        }
                      });
                    },
                    tooltip: _isFamiliarityMode ? '隐藏熟悉度' : '显示熟悉度',
                  ),
                ],
              ),
            ),
          ),
          // 添加定位按钮
          Positioned(
            bottom: 120, // 底部位置
            right: 20,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(26),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: IconButton(
                icon: const Icon(
                  Icons.my_location,
                  color: Colors.black,
                ),
                onPressed: () async {
                  final GoogleMapController controller = _mapController!;
                  controller.animateCamera(
                    CameraUpdate.newCameraPosition(
                      CameraPosition(
                        target: _center, // 这里后续需要改为实际的当前位置
                        zoom: 15,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          // 添加移动控制器
          Positioned(
            left: 20,
            bottom: 120,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(26),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Column(
                children: [
                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_up),
                    onPressed: () => _movePosition('north'),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.keyboard_arrow_left),
                        onPressed: () => _movePosition('west'),
                      ),
                      const SizedBox(width: 40),
                      IconButton(
                        icon: const Icon(Icons.keyboard_arrow_right),
                        onPressed: () => _movePosition('east'),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_down),
                    onPressed: () => _movePosition('south'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}