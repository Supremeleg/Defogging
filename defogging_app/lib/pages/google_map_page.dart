import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_google_maps_webservices/places.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'dart:math';
import 'dart:ui' as ui;
import '../services/location_service.dart';
import '../database/location_model.dart';
import 'package:flutter/rendering.dart';

// 添加自定义遮罩层绘制器
class FogOverlayPainter extends CustomPainter {
  final List<Offset> points;
  final double radius;
  final double opacity;
  final double zoomLevel; // 添加缩放级别参数

  FogOverlayPainter({
    required this.points,
    required this.radius,
    required this.opacity,
    required this.zoomLevel,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 保存画布状态
    canvas.saveLayer(Offset.zero & size, Paint());
    
    // 绘制黑色背景
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..color = Colors.black.withOpacity(opacity)
        ..style = PaintingStyle.fill,
    );
    
    // 使用BlendMode.clear绘制透明区域
    final clearPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill
      ..blendMode = BlendMode.clear;

    // 计算实际擦除半径（根据缩放级别调整）
    final actualRadius = radius * pow(2, zoomLevel - 18); // 18是基准缩放级别

    // 一次性绘制所有圆形区域
    for (var point in points) {
      canvas.drawCircle(point, actualRadius, clearPaint);
    }
    
    // 恢复画布状态
    canvas.restore();
  }

  @override
  bool shouldRepaint(FogOverlayPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.radius != radius ||
        oldDelegate.opacity != opacity ||
        oldDelegate.zoomLevel != zoomLevel;
  }
}

// 添加遥感控制器组件
class JoystickController extends StatefulWidget {
  final Function(double angle, double distance) onDirectionChanged;

  const JoystickController({
    Key? key,
    required this.onDirectionChanged,
  }) : super(key: key);

  @override
  State<JoystickController> createState() => _JoystickControllerState();
}

class _JoystickControllerState extends State<JoystickController> {
  Offset _startPosition = Offset.zero;
  Offset _currentPosition = Offset.zero;
  bool _isDragging = false;
  final double _maxDistance = 30.0; // 最大拖动距离

  void _updatePosition(Offset position) {
    final delta = position - _startPosition;
    final distance = delta.distance;
    
    if (distance > _maxDistance) {
      final normalized = delta / distance;
      _currentPosition = _startPosition + (normalized * _maxDistance);
    } else {
      _currentPosition = position;
    }

    // 计算角度和距离
    final angle = atan2(
      _currentPosition.dy - _startPosition.dy,
      _currentPosition.dx - _startPosition.dx,
    );
    final normalizedDistance = min(distance, _maxDistance) / _maxDistance;

    widget.onDirectionChanged(angle, normalizedDistance);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: GestureDetector(
        onPanStart: (details) {
          _isDragging = true;
          _startPosition = details.localPosition;
          _currentPosition = _startPosition;
        },
        onPanUpdate: (details) {
          if (_isDragging) {
            setState(() {
              _updatePosition(details.localPosition);
            });
          }
        },
        onPanEnd: (_) {
          setState(() {
            _isDragging = false;
            _currentPosition = _startPosition;
          });
          widget.onDirectionChanged(0, 0);
        },
        child: CustomPaint(
          painter: JoystickPainter(
            center: _startPosition,
            current: _currentPosition,
            isDragging: _isDragging,
          ),
        ),
      ),
    );
  }
}

class JoystickPainter extends CustomPainter {
  final Offset center;
  final Offset current;
  final bool isDragging;

  JoystickPainter({
    required this.center,
    required this.current,
    required this.isDragging,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    // 绘制底部圆形
    final centerPoint = size.center(Offset.zero);
    canvas.drawCircle(centerPoint, size.width / 2, paint);

    // 绘制操纵杆
    final stickPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.fill;

    final stickPosition = isDragging ? current : centerPoint;
    canvas.drawCircle(stickPosition, 20, stickPaint);
  }

  @override
  bool shouldRepaint(JoystickPainter oldDelegate) {
    return oldDelegate.current != current ||
        oldDelegate.isDragging != isDragging;
  }
}

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
  
  static const double _circleRadius = 5.0; // 白色标记点的半径
  static const double _eraserRadius = 20.0; // 擦除区域的半径
  // 存储地图坐标点而不是屏幕坐标点
  List<LatLng> _clearPoints = [];
  Size? _mapSize;

  // 添加地图边界
  LatLngBounds? _visibleRegion;

  bool _showTrackingPoints = true; // 添加控制白点显示的状态

  // 获取遮罩不透明度
  double get _overlayOpacity {
    return 0.7;
  }

  // 添加坐标转换方法
  Offset? _latLngToScreenPoint(LatLng latLng) {
    if (_visibleRegion == null || _mapSize == null || _mapController == null) return null;

    final ne = _visibleRegion!.northeast;
    final sw = _visibleRegion!.southwest;
    
    final width = _mapSize!.width;
    final height = _mapSize!.height;

    final x = (latLng.longitude - sw.longitude) / (ne.longitude - sw.longitude) * width;
    final y = (1 - (latLng.latitude - sw.latitude) / (ne.latitude - sw.latitude)) * height;

    return Offset(x, y);
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
  void _movePosition(String direction) async {
    if (_mapController == null) return;

    setState(() {
      _currentPosition = _calculateOffset(_currentPosition, 2.0, direction);
      
      _markers.clear();
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
      
      if (_isTracking) {
        if (_showTrackingPoints) { // 只在显示白点时添加Circle
          _circles.add(
            Circle(
              circleId: CircleId(DateTime.now().toString()),
              center: _currentPosition,
              radius: _circleRadius,
              fillColor: Colors.white.withOpacity(0.7),
              strokeColor: Colors.white,
              strokeWidth: 1,
            ),
          );
        }
        // 无论是否显示白点，都要记录清除点
        _clearPoints.add(_currentPosition);
      }
    });

    // 更新可见区域
    _visibleRegion = await _mapController!.getVisibleRegion();
    setState(() {}); // 触发重绘以更新遮罩层

    _mapController?.animateCamera(
      CameraUpdate.newLatLng(_currentPosition),
    );
  }

  // 添加斜向移动方法
  void _movePositionDiagonal(String direction1, String direction2) {
    // 计算斜向移动的位置
    final pos1 = _calculateOffset(_currentPosition, 1.4, direction1); // 减小单方向距离以保持斜向距离合适
    final pos2 = _calculateOffset(pos1, 1.4, direction2);
    
    setState(() {
      _currentPosition = pos2;
      
      _markers.clear();
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
      
      if (_isTracking) {
        if (_showTrackingPoints) {
          _circles.add(
            Circle(
              circleId: CircleId(DateTime.now().toString()),
              center: _currentPosition,
              radius: _circleRadius,
              fillColor: Colors.white.withOpacity(0.7),
              strokeColor: Colors.white,
              strokeWidth: 1,
            ),
          );
        }
        _clearPoints.add(_currentPosition);
      }
    });

    _mapController?.animateCamera(
      CameraUpdate.newLatLng(_currentPosition),
    );
  }

  // 添加遥感控制方法
  void _onJoystickDirectionChanged(double angle, double distance) {
    if (distance == 0) return; // 如果没有移动，直接返回

    // 将弧度转换为角度
    final degrees = (angle * 180 / pi + 360) % 360;
    
    // 计算移动方向
    String direction1 = '';
    String direction2 = '';
    
    if (degrees >= 337.5 || degrees < 22.5) {
      direction1 = 'east';
    } else if (degrees >= 22.5 && degrees < 67.5) {
      direction1 = 'south';
      direction2 = 'east';
    } else if (degrees >= 67.5 && degrees < 112.5) {
      direction1 = 'south';
    } else if (degrees >= 112.5 && degrees < 157.5) {
      direction1 = 'south';
      direction2 = 'west';
    } else if (degrees >= 157.5 && degrees < 202.5) {
      direction1 = 'west';
    } else if (degrees >= 202.5 && degrees < 247.5) {
      direction1 = 'north';
      direction2 = 'west';
    } else if (degrees >= 247.5 && degrees < 292.5) {
      direction1 = 'north';
    } else if (degrees >= 292.5 && degrees < 337.5) {
      direction1 = 'north';
      direction2 = 'east';
    }

    // 根据方向移动
    if (direction2.isEmpty) {
      _movePosition(direction1);
    } else {
      _movePositionDiagonal(direction1, direction2);
    }
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

  void _onMapCreated(GoogleMapController controller) async {
    _mapController = controller;
    _addMarker(_currentPosition);
    if (_isFamiliarityMode) {
      controller.setMapStyle(_mapStyle);
    }
    
    // 获取初始可见区域
    _visibleRegion = await controller.getVisibleRegion();
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

  double _currentZoom = 18.0; // 添加当前缩放级别状态

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        _mapSize = Size(constraints.maxWidth, constraints.maxHeight);
        
        // 转换所有清除点的坐标
        final screenPoints = _clearPoints
            .map((latLng) => _latLngToScreenPoint(latLng))
            .where((point) => point != null)
            .cast<Offset>()
            .toList();

        return Stack(
          children: [
            GoogleMap(
              onMapCreated: _onMapCreated,
              initialCameraPosition: CameraPosition(
                target: _center,
                zoom: 18.0,
                tilt: 0, // 禁用3D旋转
              ),
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapType: MapType.normal,
              markers: _markers,
              circles: _showTrackingPoints ? _circles : {},
              onCameraMove: (CameraPosition position) async {
                if (_mapController != null && mounted) {
                  _visibleRegion = await _mapController!.getVisibleRegion();
                  setState(() {
                    _currentZoom = position.zoom; // 更新当前缩放级别
                  });
                }
              },
              tiltGesturesEnabled: false, // 禁用倾斜手势
              rotateGesturesEnabled: false, // 禁用旋转手势
            ),
            if (_isFamiliarityMode)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: FogOverlayPainter(
                      points: screenPoints,
                      radius: _eraserRadius,
                      opacity: _overlayOpacity,
                      zoomLevel: _currentZoom, // 传递当前缩放级别
                    ),
                    size: _mapSize ?? Size.zero,
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
              child: JoystickController(
                onDirectionChanged: _onJoystickDirectionChanged,
              ),
            ),
            // 添加白点显示控制按钮
            Positioned(
              left: 20,
              bottom: 300, // 放在方向控制器上方
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
                  icon: Icon(
                    _showTrackingPoints ? Icons.circle : Icons.circle_outlined,
                    color: _showTrackingPoints ? Colors.blue : Colors.grey,
                  ),
                  onPressed: () {
                    setState(() {
                      _showTrackingPoints = !_showTrackingPoints;
                    });
                  },
                  tooltip: _showTrackingPoints ? '隐藏轨迹点' : '显示轨迹点',
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}