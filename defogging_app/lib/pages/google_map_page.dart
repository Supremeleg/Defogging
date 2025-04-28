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
import 'package:flutter_google_maps_webservices/geocoding.dart';

// 添加自定义遮罩层绘制器
class FogOverlayPainter extends CustomPainter {
  final List<Offset> points;
  final double radius;
  final double opacity;
  final double zoomLevel;

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
    final actualRadius = radius * pow(2, zoomLevel - 18);

    // 为每个点创建羽化效果
    for (var point in points) {
      // 创建径向渐变
      final gradient = RadialGradient(
        colors: [
          Colors.white.withOpacity(1.0),
          Colors.white.withOpacity(0.0),
        ],
        stops: const [0.7, 1.0],
      );

      // 创建渐变画笔
      final gradientPaint = Paint()
        ..shader = gradient.createShader(
          Rect.fromCircle(
            center: point,
            radius: actualRadius,
          ),
        )
        ..blendMode = BlendMode.clear;

      // 绘制羽化效果
      canvas.drawCircle(point, actualRadius, gradientPaint);
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
        color: Colors.black.withOpacity(0.2),
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
    final centerPoint = size.center(Offset.zero);
    // 绘制底部圆形（20%黑色半透明）
    final basePaint = Paint()
      ..color = Colors.black.withOpacity(0.2)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(centerPoint, size.width / 2, basePaint);

    // 添加白色外发光阴影
    final shadowPaint = Paint()
      ..color = Colors.white.withOpacity(0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawCircle(centerPoint, size.width / 2 - 4, shadowPaint);

    // 绘制操纵杆（纯白色）
    final stickPaint = Paint()
      ..color = Colors.white
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
  LatLng _center = const LatLng(51.5074, -0.1278);
  Set<Marker> _markers = {};
  final TextEditingController _searchController = TextEditingController();
  late final GoogleMapsPlaces _placesService;
  LatLng _currentPosition = const LatLng(51.5074, -0.1278);
  final LocationService _locationService = LocationService();
  bool _isTracking = false;
  bool _isFamiliarityMode = true;
  double _familiarityPercentage = 75.0;
  static const double _eraserRadius = 20.0;
  List<LatLng> _clearPoints = [];
  Size? _mapSize;
  LatLngBounds? _visibleRegion;
  double _currentZoom = 18.0;
  bool _isPlacingMode = false;
  bool _isSearchBarOpen = false;

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
        _clearPoints.add(_currentPosition);
      }
    });
    if (_isTracking) {
      await _locationService.saveVirtualLocation(_currentPosition);
    }
    _visibleRegion = await _mapController!.getVisibleRegion();
    setState(() {});
    _mapController?.animateCamera(
      CameraUpdate.newLatLng(_currentPosition),
    );
  }

  // 添加斜向移动方法
  void _movePositionDiagonal(String direction1, String direction2) async {
    final pos1 = _calculateOffset(_currentPosition, 1.4, direction1);
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
        _clearPoints.add(_currentPosition);
      }
    });
    if (_isTracking) {
      await _locationService.saveVirtualLocation(_currentPosition);
    }
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

    // 获取初始位置
    _getCurrentLocation();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadLocations(); // 在依赖变化时重新加载
  }

  void _onLocationUpdated(LocationPoint location) {
    setState(() {
      _currentPosition = LatLng(location.latitude, location.longitude);
      final markerId = MarkerId(location.id?.toString() ?? DateTime.now().toString());
      _markers.removeWhere((marker) => marker.markerId == markerId);
      _markers.add(
        Marker(
          markerId: markerId,
          position: _currentPosition,
          infoWindow: InfoWindow(
            title: '当前位置',
            snippet: '纬度: ${_currentPosition.latitude}, 经度: ${_currentPosition.longitude}',
          ),
        ),
      );
      _clearPoints.add(_currentPosition);
    });
  }

  Future<void> _loadLocations() async {
    try {
      final locations = await _locationService.getAllLocations();
      if (!mounted) return;
      setState(() {
        _clearPoints.clear();
        for (var location in locations) {
          _clearPoints.add(LatLng(location.latitude, location.longitude));
        }
      });
      // 自动跳转到历史点中心
      if (_clearPoints.isNotEmpty && _mapController != null) {
        double avgLat = _clearPoints.map((e) => e.latitude).reduce((a, b) => a + b) / _clearPoints.length;
        double avgLng = _clearPoints.map((e) => e.longitude).reduce((a, b) => a + b) / _clearPoints.length;
        _mapController!.animateCamera(CameraUpdate.newLatLng(LatLng(avgLat, avgLng)));
      }
      print('_clearPoints: \n$_clearPoints');
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
      
      // 记录清除点
      _clearPoints.add(position);
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

  // 添加获取当前位置的方法
  Future<void> _getCurrentLocation() async {
    try {
      final location = await _locationService.getCurrentLocation();
      if (location != null) {
        setState(() {
          _currentPosition = LatLng(location.latitude, location.longitude);
          _center = _currentPosition;
          _addMarker(_currentPosition);
        });
        
        // 移动地图到当前位置
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(_currentPosition, 18.0),
        );
      }
    } catch (e) {
      print('获取当前位置失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        _mapSize = Size(constraints.maxWidth, constraints.maxHeight);
        
        // 转换所有清除点的坐标
        final screenPoints = _clearPoints
            .map((latLng) => _latLngToScreenPoint(latLng))
            .where((point) => point != null && point.dx > 0 && point.dy > 0 && _mapSize != null && point.dx < _mapSize!.width && point.dy < _mapSize!.height)
            .cast<Offset>()
            .toList();
        print('screenPoints: $screenPoints');

        return Stack(
          children: [
            GoogleMap(
              onMapCreated: _onMapCreated,
              initialCameraPosition: CameraPosition(
                target: _center,
                zoom: 18.0,
                tilt: 0, // 禁用3D旋转
              ),
              myLocationEnabled: false,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapType: MapType.normal,
              markers: {}, // 不显示Google Maps自带的Marker
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
              onTap: _isPlacingMode
                  ? (latLng) {
                      setState(() {
                        _currentPosition = latLng;
                        _isPlacingMode = false;
                      });
                      _addMarker(latLng);
                      _mapController?.animateCamera(
                        CameraUpdate.newLatLng(latLng),
                      );
                    }
                  : null,
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
            // 自定义红色标记和发光白色圆点
            if (_mapSize != null && _visibleRegion != null)
              ...[
                // 红色标记（character1.png）
                if (_latLngToScreenPoint(_currentPosition) != null)
                  Positioned(
                    left: _latLngToScreenPoint(_currentPosition)!.dx - 24,
                    top: _latLngToScreenPoint(_currentPosition)!.dy - 48,
                    child: Image.asset(
                      'assets/character1.png',
                      width: 48,
                      height: 48,
                    ),
                  ),
                // 蓝色发光圆点（真实位置）
                if (_latLngToScreenPoint(_center) != null)
                  Positioned(
                    left: _latLngToScreenPoint(_center)!.dx - 16,
                    top: _latLngToScreenPoint(_center)!.dy - 16,
                    child: _GlowingWhiteDot(),
                  ),
              ],
            // 顶部搜索栏和按钮
            Positioned(
              top: 60,
              right: 15,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.ease,
                width: _isSearchBarOpen ? 280 : 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(26),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // 展开时显示输入框
                    if (_isSearchBarOpen)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 12),
                          child: TextField(
                            controller: _searchController,
                            decoration: const InputDecoration(
                              hintText: '搜索地点...',
                              border: InputBorder.none,
                              isDense: true,
                            ),
                            onSubmitted: _searchPlaces,
                            autofocus: true,
                          ),
                        ),
                      ),
                    // 搜索按钮
                    IconButton(
                      icon: const Icon(Icons.search, color: Colors.white),
                      onPressed: () {
                        setState(() {
                          if (_isSearchBarOpen) {
                            // 已展开时点击，执行搜索
                            _searchPlaces(_searchController.text);
                          }
                          _isSearchBarOpen = !_isSearchBarOpen;
                        });
                      },
                      tooltip: '搜索',
                    ),
                  ],
                ),
              ),
            ),
            // 添加熟悉度切换按钮
            Positioned(
              bottom: 280,
              right: 20,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.2),
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
                    // 位置跟踪开关
                    IconButton(
                      icon: Icon(
                        _isTracking ? Icons.location_on : Icons.location_off,
                        color: Colors.white,
                      ),
                      onPressed: _toggleTracking,
                      tooltip: _isTracking ? '停止位置跟踪' : '开始位置跟踪',
                    ),
                    // 熟悉度显示开关
                    IconButton(
                      icon: Icon(
                        _isFamiliarityMode ? Icons.visibility : Icons.visibility_off,
                        color: Colors.white,
                      ),
                      onPressed: () {
                        setState(() {
                          _isFamiliarityMode = !_isFamiliarityMode;
                          if (_isFamiliarityMode) {
                            _mapController?.setMapStyle(_mapStyle);
                          } else {
                            _mapController?.setMapStyle(null);
                          }
                        });
                      },
                      tooltip: _isFamiliarityMode ? '隐藏熟悉度' : '显示熟悉度',
                    ),
                  ],
                ),
              ),
            ),
            // 添加缩放控制按钮
            Positioned(
              bottom: 175,
              right: 20,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.2),
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
                    // 放大按钮
                    IconButton(
                      icon: const Icon(
                        Icons.add,
                        color: Colors.white,
                      ),
                      onPressed: () {
                        if (_mapController != null) {
                          _mapController!.animateCamera(
                            CameraUpdate.zoomIn(),
                          );
                        }
                      },
                      tooltip: '放大',
                    ),
                    // 缩小按钮
                    IconButton(
                      icon: const Icon(
                        Icons.remove,
                        color: Colors.white,
                      ),
                      onPressed: () {
                        if (_mapController != null) {
                          _mapController!.animateCamera(
                            CameraUpdate.zoomOut(),
                          );
                        }
                      },
                      tooltip: '缩小',
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
                  color: Colors.black.withOpacity(0.2),
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
                    color: Colors.white,
                  ),
                  onPressed: () {
                    if (_mapController != null) {
                      _mapController!.animateCamera(
                        CameraUpdate.newLatLngZoom(_currentPosition, _currentZoom),
                      );
                    }
                  },
                ),
              ),
            ),
            // 添加移动控制器和放置按钮
            Positioned(
              left: 20,
              bottom: 120,
              child: JoystickController(
                onDirectionChanged: _onJoystickDirectionChanged,
              ),
            ),
            // 放置模式按钮
            Positioned(
              left: 20,
              bottom: 280,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.2),
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
                    Icons.place,
                    color: _isPlacingMode ? Colors.blue : Colors.white,
                    size: 24,
                  ),
                  onPressed: () {
                    setState(() {
                      _isPlacingMode = !_isPlacingMode;
                    });
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// 修改发光白色圆点组件
class _GlowingWhiteDot extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24, // 缩小整体尺寸
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.white.withOpacity(0.5), // 发光更弱
            blurRadius: 8, // 扩散范围更小
            spreadRadius: 3,
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}