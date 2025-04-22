import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_google_maps_webservices/places.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

class GoogleMapPage extends StatefulWidget {
  const GoogleMapPage({super.key});

  @override
  State<GoogleMapPage> createState() => _GoogleMapPageState();
}

class _GoogleMapPageState extends State<GoogleMapPage> {
  late GoogleMapController mapController;
  final LatLng _center = const LatLng(51.5074, -0.1278); // 伦敦坐标
  final Set<Marker> _markers = {};
  final TextEditingController _searchController = TextEditingController();
  late final GoogleMapsPlaces _placesService;
  
  // 添加熟悉度状态
  bool _isFamiliarityMode = true; // 默认开启熟悉度显示模式
  
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

  @override
  void initState() {
    super.initState();
    _placesService = GoogleMapsPlaces(apiKey: dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '');
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
    _addMarker(_center);
    // 应用地图样式
    controller.setMapStyle(_mapStyle);
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

        mapController.animateCamera(
          CameraUpdate.newLatLngZoom(newPosition, 15),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('搜索出错: $e');
      }
    }
  }

  @override
  void dispose() {
    mapController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(
              target: _center,
              zoom: 11.0,
            ),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapType: MapType.normal,
            markers: _markers,
          ),
          // 添加熟悉度遮罩层
          if (_isFamiliarityMode)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(_overlayOpacity),
              ),
            ),
          Positioned(
            top: 60,
            left: 15,
            right: 15,
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
              child: IconButton(
                icon: Icon(
                  _isFamiliarityMode ? Icons.visibility : Icons.visibility_off,
                  color: _isFamiliarityMode ? Colors.black : Colors.grey,
                ),
                onPressed: () {
                  setState(() {
                    _isFamiliarityMode = !_isFamiliarityMode;
                  });
                },
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
                  final GoogleMapController controller = mapController;
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
        ],
      ),
    );
  }
}