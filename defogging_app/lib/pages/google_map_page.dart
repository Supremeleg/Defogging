import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class GoogleMapPage extends StatefulWidget {
  const GoogleMapPage({super.key});

  @override
  State<GoogleMapPage> createState() => _GoogleMapPageState();
}

class _GoogleMapPageState extends State<GoogleMapPage> {
  late GoogleMapController mapController;
  final LatLng _center = const LatLng(51.5074, -0.1278); // 伦敦坐标
  Set<Marker> _markers = {};

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
    _addMarker(_center);
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

  @override
  void dispose() {
    mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GoogleMap(
        onMapCreated: _onMapCreated,
        initialCameraPosition: CameraPosition(
          target: _center,
          zoom: 11.0,
        ),
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
        mapType: MapType.normal,
        markers: _markers,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final position = await mapController.getVisibleRegion();
          final center = LatLng(
            (position.northeast.latitude + position.southwest.latitude) / 2,
            (position.northeast.longitude + position.southwest.longitude) / 2,
          );
          _addMarker(center);
        },
        child: const Icon(Icons.location_on),
      ),
    );
  }
}