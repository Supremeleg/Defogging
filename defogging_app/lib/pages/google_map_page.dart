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
import '../services/event_service.dart';
import '../models/event_model.dart';
import '../models/card_model.dart';
import '../services/card_service.dart';

// Add custom overlay painter
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
    // Save canvas state
    canvas.saveLayer(Offset.zero & size, Paint());
    
    // Create gradient from outside to inside
    final gradient = RadialGradient(
      center: Alignment.center,
      radius: 1.0,
      colors: [
        Colors.black.withOpacity(0.0),
        Colors.black.withOpacity(opacity * 0.2),
        Colors.black.withOpacity(opacity * 0.4),
        Colors.black.withOpacity(opacity * 0.6),
        Colors.black.withOpacity(opacity * 0.8),
        Colors.black.withOpacity(opacity),
      ],
      stops: const [0.0, 0.2, 0.4, 0.6, 0.8, 1.0],
    );

    // Draw gradient background
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = gradient.createShader(
          Rect.fromLTWH(0, 0, size.width, size.height),
        )
        ..style = PaintingStyle.fill,
    );
    
    // Use BlendMode.clear to draw transparent areas
    final clearPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill
      ..blendMode = BlendMode.clear;

    // Calculate actual erasure radius (adjusted based on zoom level)
    final actualRadius = radius * pow(2, zoomLevel - 18);

    // Create feathering effect for each point
    for (var point in points) {
      // Create radial gradient
      final pointGradient = RadialGradient(
        colors: [
          Colors.white.withOpacity(1.0),
          Colors.white.withOpacity(0.0),
        ],
        stops: const [0.7, 1.0],
      );

      // Create gradient brush
      final gradientPaint = Paint()
        ..shader = pointGradient.createShader(
          Rect.fromCircle(
            center: point,
            radius: actualRadius,
          ),
        )
        ..blendMode = BlendMode.clear;

      // Draw feathering effect
      canvas.drawCircle(point, actualRadius, gradientPaint);
    }
    
    // Restore canvas state
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

// Add joystick controller component
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
  final double _maxDistance = 30.0; // Maximum drag distance

  void _updatePosition(Offset position) {
    final delta = position - _startPosition;
    final distance = delta.distance;
    
    if (distance > _maxDistance) {
      final normalized = delta / distance;
      _currentPosition = _startPosition + (normalized * _maxDistance);
    } else {
      _currentPosition = position;
    }

    // Calculate angle and distance
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
    // Draw bottom circle (20% black semi-transparent)
    final basePaint = Paint()
      ..color = Colors.black.withOpacity(0.2)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(centerPoint, size.width / 2, basePaint);

    // Add white outer glow shadow
    final shadowPaint = Paint()
      ..color = Colors.white.withOpacity(0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawCircle(centerPoint, size.width / 2 - 4, shadowPaint);

    // Draw joystick (pure white)
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
  double _currentZoom = 22.0;
  bool _isPlacingMode = false;
  bool _isSearchBarOpen = false;
  final EventService _eventService = EventService();
  List<MapEvent> _discoveredEvents = [];
  bool _showEventDialog = false;
  MapEvent? _currentEvent;
  final CardService _cardService = CardService();
  List<CardModel> _collectedCards = [];
  bool _showCardDialog = false;
  CardModel? _currentCard;
  List<CardModel> _randomCards = []; // 添加一个变量来存储生成的卡片

  // Get overlay opacity
  double get _overlayOpacity {
    return 0.7;
  }

  // Add coordinate conversion method
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

  // Add map style list
  final Map<String, String> _mapStyles = {
    'Default': '',
    'Deep Purple': '''
    [
      {
        "featureType": "poi",
        "elementType": "labels",
        "stylers": [
          {
            "visibility": "off"
          }
        ]
      },
      {
        "featureType": "poi.business",
        "stylers": [
          {
            "visibility": "off"
          }
        ]
      },
      {
        "featureType": "poi.park",
        "elementType": "labels.text",
        "stylers": [
          {
            "visibility": "off"
          }
        ]
      },
      {
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#1a1a2f"
          }
        ]
      },
      {
        "elementType": "labels.text.fill",
        "stylers": [
          {
            "color": "#8e8eb3"
          }
        ]
      },
      {
        "elementType": "labels.text.stroke",
        "stylers": [
          {
            "color": "#1a1a2f"
          }
        ]
      },
    {
      "featureType": "landscape",
      "elementType": "geometry",
      "stylers": [
        {
            "color": "#252538"
        }
      ]
    },
    {
      "featureType": "road",
      "elementType": "geometry",
      "stylers": [
        {
            "color": "#2d2d44"
        }
      ]
    },
    {
      "featureType": "road.arterial",
      "elementType": "labels.text.fill",
      "stylers": [
        {
            "color": "#9d9dc6"
        }
      ]
    },
    {
      "featureType": "road.highway",
      "elementType": "geometry",
      "stylers": [
        {
            "color": "#3d3d5c"
        }
      ]
    },
    {
      "featureType": "water",
      "elementType": "geometry",
      "stylers": [
        {
            "color": "#151525"
          }
        ]
      },
      {
        "featureType": "poi",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#2a2a40"
          }
        ]
      },
      {
        "featureType": "transit",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#2d2d44"
          }
        ]
      }
    ]
    ''',
    'Minimalist Black and White': '''
    [
      {
        "featureType": "poi",
        "stylers": [
          {
            "visibility": "off"
          }
        ]
      },
      {
        "featureType": "poi.business",
        "stylers": [
          {
            "visibility": "off"
          }
        ]
      },
      {
        "featureType": "poi.park",
        "elementType": "labels.text",
        "stylers": [
          {
            "visibility": "off"
          }
        ]
      },
      {
        "featureType": "water",
        "elementType": "all",
        "stylers": [
          {
            "hue": "#ffffff"
          },
          {
            "saturation": -100
          },
          {
            "lightness": 100
          },
          {
            "visibility": "on"
          }
        ]
      },
      {
        "featureType": "landscape",
        "elementType": "all",
        "stylers": [
          {
            "hue": "#ffffff"
          },
          {
            "saturation": -100
          },
          {
            "lightness": 100
          },
          {
            "visibility": "on"
          }
        ]
      },
      {
        "featureType": "road",
        "elementType": "geometry",
        "stylers": [
          {
            "hue": "#000000"
          },
          {
            "saturation": -100
          },
          {
            "lightness": -100
          },
          {
            "visibility": "simplified"
          }
        ]
      },
      {
        "featureType": "road",
        "elementType": "labels",
        "stylers": [
          {
            "visibility": "off"
          }
        ]
      },
      {
        "featureType": "poi",
        "elementType": "all",
        "stylers": [
          {
            "visibility": "off"
          }
        ]
      },
      {
        "featureType": "administrative",
        "elementType": "all",
        "stylers": [
          {
            "visibility": "off"
          }
        ]
      },
      {
        "featureType": "transit",
        "elementType": "geometry",
        "stylers": [
          {
            "hue": "#000000"
          },
          {
            "lightness": -100
          },
          {
            "visibility": "on"
          }
        ]
      }
    ]
    ''',
    'Midnight Blue': '''
    [
      {
        "featureType": "poi",
        "stylers": [
          {
            "visibility": "off"
          }
        ]
      },
      {
        "featureType": "poi.business",
        "stylers": [
          {
            "visibility": "off"
          }
        ]
      },
      {
        "featureType": "poi.park",
        "elementType": "labels.text",
        "stylers": [
          {
            "visibility": "off"
          }
        ]
      },
      {
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#334155"
          }
        ]
      },
      {
        "featureType": "road.highway",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#475569"
          }
        ]
      },
      {
        "featureType": "water",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#0c4a6e"
          }
        ]
      },
      {
        "featureType": "poi",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#1e293b"
          }
        ]
      },
      {
        "featureType": "transit",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#334155"
          }
        ]
      }
    ]
    ''',
    'Retro Brown': '''
    [
      {
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#2b1d0e"
          }
        ]
      },
      {
        "elementType": "labels.text.fill",
        "stylers": [
          {
            "color": "#d5b088"
          }
        ]
      },
      {
        "featureType": "landscape",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#3c2915"
          }
        ]
      },
      {
        "featureType": "road",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#4a3321"
          }
        ]
      },
      {
        "featureType": "water",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#1a1105"
          }
        ]
      }
    ]
    ''',
    'Aurora': '''
    [
      {
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#1c2754"
          }
        ]
      },
      {
        "elementType": "labels.text.fill",
        "stylers": [
          {
            "color": "#8ec3b9"
          }
        ]
      },
      {
        "featureType": "landscape",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#2a3d66"
          }
        ]
      },
      {
        "featureType": "road",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#38b6ff"
          },
          {
            "lightness": 20
          }
        ]
      },
      {
        "featureType": "road.highway",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#4dc9ff"
          }
        ]
      },
      {
        "featureType": "water",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#0f3057"
          }
        ]
      },
      {
        "featureType": "poi",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#2d4b73"
          }
        ]
      },
      {
        "featureType": "transit",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#2a3d66"
          }
        ]
      }
    ]
    ''',
    'Sunset': '''
    [
      {
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#ff7b54"
          }
        ]
      },
      {
        "elementType": "labels.text.fill",
        "stylers": [
          {
            "color": "#ffb26b"
          }
        ]
      },
      {
        "featureType": "landscape",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#ffd56b"
          },
          {
            "lightness": -10
          }
        ]
      },
      {
        "featureType": "road",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#ff7b54"
          },
          {
            "lightness": 20
          }
        ]
      },
      {
        "featureType": "road.highway",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#ff6b6b"
          }
        ]
      },
      {
        "featureType": "water",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#4f9da6"
          }
        ]
      },
      {
        "featureType": "poi",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#ffb26b"
          },
          {
            "lightness": -15
          }
        ]
      }
    ]
    ''',
    'Dream': '''
    [
      {
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#c9d6ff"
          }
        ]
      },
      {
        "elementType": "labels.text.fill",
        "stylers": [
          {
            "color": "#9ba5d3"
          }
        ]
      },
      {
        "featureType": "landscape",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#e2e2ff"
          }
        ]
      },
      {
        "featureType": "road",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#b8c6db"
          },
          {
            "lightness": 20
          }
        ]
      },
      {
        "featureType": "road.highway",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#a1c4fd"
          }
        ]
      },
      {
        "featureType": "water",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#8ec5fc"
          }
        ]
      },
      {
        "featureType": "poi",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#d4d4ff"
          }
        ]
      },
      {
        "featureType": "transit",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#c2e9fb"
          }
        ]
      }
    ]
    ''',
    'Christmas': '''
    [
      {
        "featureType": "poi",
        "elementType": "labels",
        "stylers": [
          {
            "visibility": "off"
          }
        ]
      },
      {
        "featureType": "poi.business",
        "stylers": [
          {
            "visibility": "off"
          }
        ]
      },
      {
        "featureType": "poi.park",
        "elementType": "labels.text",
        "stylers": [
          {
            "visibility": "off"
          }
        ]
      },
      {
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#1a2c1a"
          }
        ]
      },
      {
        "elementType": "labels.text.fill",
        "stylers": [
          {
            "color": "#8ec6ad"
          }
        ]
      },
      {
        "featureType": "landscape",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#1a2c1a"
          }
        ]
      },
      {
        "featureType": "road",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#2d4d2d"
          }
        ]
      },
      {
        "featureType": "road.highway",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#3d6d3d"
          }
        ]
      },
      {
        "featureType": "water",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#0d1c0d"
          }
        ]
      }
    ]
    ''',
    'Spring Festival': '''
    [
      {
        "featureType": "poi",
        "elementType": "labels",
        "stylers": [
          {
            "visibility": "off"
          }
        ]
      },
      {
        "featureType": "poi.business",
        "stylers": [
          {
            "visibility": "off"
          }
        ]
      },
      {
        "featureType": "poi.park",
        "elementType": "labels.text",
        "stylers": [
          {
            "visibility": "off"
          }
        ]
      },
      {
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#2c1a1a"
          }
        ]
      },
      {
        "elementType": "labels.text.fill",
        "stylers": [
          {
            "color": "#c68e8e"
          }
        ]
      },
      {
        "featureType": "landscape",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#2c1a1a"
          }
        ]
      },
      {
        "featureType": "road",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#4d2d2d"
          }
        ]
      },
      {
        "featureType": "road.highway",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#6d3d3d"
          }
        ]
      },
      {
        "featureType": "water",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#1c0d0d"
          }
        ]
      }
    ]
    ''',
    'Mid-Autumn Festival': '''
    [
      {
        "featureType": "poi",
        "elementType": "labels",
        "stylers": [
          {
            "visibility": "off"
          }
        ]
      },
      {
        "featureType": "poi.business",
        "stylers": [
          {
            "visibility": "off"
          }
        ]
      },
      {
        "featureType": "poi.park",
        "elementType": "labels.text",
        "stylers": [
          {
            "visibility": "off"
          }
        ]
      },
      {
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#1a1a2c"
          }
        ]
      },
      {
        "elementType": "labels.text.fill",
        "stylers": [
          {
            "color": "#8e8ec6"
          }
        ]
      },
      {
        "featureType": "landscape",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#1a1a2c"
          }
        ]
      },
      {
        "featureType": "road",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#2d2d4d"
          }
        ]
      },
      {
        "featureType": "road.highway",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#3d3d6d"
          }
        ]
      },
      {
        "featureType": "water",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#0d0d1c"
          }
        ]
      }
    ]
    ''',
    'Valentine\'s Day': '''
    [
      {
        "featureType": "poi",
        "elementType": "labels",
        "stylers": [
          {
            "visibility": "off"
          }
        ]
      },
      {
        "featureType": "poi.business",
        "stylers": [
          {
            "visibility": "off"
          }
        ]
      },
      {
        "featureType": "poi.park",
        "elementType": "labels.text",
        "stylers": [
          {
            "visibility": "off"
          }
        ]
      },
      {
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#2c1a2c"
          }
        ]
      },
      {
        "elementType": "labels.text.fill",
        "stylers": [
          {
            "color": "#ffb6c1"
          }
        ]
      },
      {
        "featureType": "landscape",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#2c1a2c"
          }
        ]
      },
      {
        "featureType": "road",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#4d2d4d"
          }
        ]
      },
      {
        "featureType": "road.highway",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#6d3d6d"
          }
        ]
      },
      {
        "featureType": "water",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#1c0d1c"
          }
        ]
      }
    ]
    '''
  };

  // Add scene recommendation mapping
  final Map<String, String> _sceneRecommendations = {
    'Daytime Exploration': 'Minimalist Black and White',
    'Night Exploration': 'Deep Purple',
    'Dusk Exploration': 'Sunset',
    'Rainy Exploration': 'Midnight Blue',
    'Retro Exploration': 'Retro Brown',
    'Dream Exploration': 'Dream',
    'Arctic Exploration': 'Aurora',
    'Christmas Exploration': 'Christmas',
    'Spring Festival Exploration': 'Spring Festival',
    'Mid-Autumn Festival Exploration': 'Mid-Autumn Festival',
    'Valentine\'s Day Exploration': 'Valentine\'s Day'
  };

  String _currentMapStyle = ''; // Initialize as empty string

  // Get scene recommendation
  String _getSceneRecommendation() {
    final hour = DateTime.now().hour;
    final now = DateTime.now();
    final month = now.month;
    final day = now.day;
    
    // Check for holidays
    if (month == 12 && day >= 20 && day <= 26) {
      return _sceneRecommendations['Christmas Exploration']!;
    } else if (month == 1 && day >= 20 && day <= 26) {
      return _sceneRecommendations['Spring Festival Exploration']!;
    } else if (month == 10 && day >= 28 && day <= 31) {
      return _sceneRecommendations['Mid-Autumn Festival Exploration']!;
    } else if (month == 9 && day >= 15 && day <= 17) {
      return _sceneRecommendations['Valentine\'s Day Exploration']!;
    } else if (month == 2 && day >= 12 && day <= 14) {
      return _sceneRecommendations['Valentine\'s Day Exploration']!;
    }
    
    // Select daily style based on time
    if (hour >= 19 || hour < 6) {
      return _sceneRecommendations['Night Exploration']!;
    } else if (hour >= 16 && hour < 19) {
      return _sceneRecommendations['Dusk Exploration']!;
    } else {
      return _sceneRecommendations['Daytime Exploration']!;
    }
  }

  // Change map style
  void _changeMapStyle(String styleName) {
    setState(() {
      _currentMapStyle = styleName;
      if (_mapController != null) {
        _mapController!.setMapStyle(_mapStyles[styleName]);
      }
    });
  }

  // Calculate latitude and longitude offset
  LatLng _calculateOffset(LatLng position, double distanceMeters, String direction) {
    // Earth radius (meters)
    const double earthRadius = 6371000;
    
    // Convert distance to radians
    double distanceRadians = distanceMeters / earthRadius;
    
    // Latitude and longitude of current position (radians)
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
    
    // Convert back to degrees
    return LatLng(
      newLatRad * (180 / pi),
      newLngRad * (180 / pi),
    );
  }

  // Move position
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
            title: 'Current Position',
            snippet: 'Latitude: ${_currentPosition.latitude}, Longitude: ${_currentPosition.longitude}',
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

  // Add diagonal movement method
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
            title: 'Current Position',
            snippet: 'Latitude: ${_currentPosition.latitude}, Longitude: ${_currentPosition.longitude}',
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

  // Add joystick control method
  void _onJoystickDirectionChanged(double angle, double distance) {
    if (distance == 0) return; // If no movement, return immediately

    // Convert angle to degrees
    final degrees = (angle * 180 / pi + 360) % 360;
    
    // Calculate movement direction
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

    // Move based on direction
    if (direction2.isEmpty) {
      _movePosition(direction1);
    } else {
      _movePositionDiagonal(direction1, direction2);
    }
  }

  @override
  bool get wantKeepAlive => true; // Keep page state

  @override
  void initState() {
    super.initState();
    _placesService = GoogleMapsPlaces(apiKey: dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '');
    _loadLocations();
    
    // Set location update callback
    _locationService.onLocationUpdated = _onLocationUpdated;
    
    // Default to location tracking
    _isTracking = true;
    _locationService.startLocationTracking();

    // Get initial position
    _getCurrentLocation();

    // Select style based on scene automatically
    _currentMapStyle = _getSceneRecommendation();

    // Initialize event system
    _initEventSystem();
    _loadCollectedCards();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadLocations(); // Reload when dependencies change
  }

  // Initialize event system
  Future<void> _initEventSystem() async {
    await _eventService.loadEvents();
    _eventService.addOnEventDiscoveredListener(_onEventDiscovered);
    
    // If there are events in the current visible area, generate new events
    if (_visibleRegion != null) {
      await _eventService.generateEventsInArea(_visibleRegion!, 5);
    }
  }

  // Event discovery callback
  void _onEventDiscovered(MapEvent event) {
    setState(() {
      _currentEvent = event;
      _showEventDialog = true;
      _discoveredEvents.add(event);
    });
  }

  // Show event dialog
  void _showEventDetails(MapEvent event) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(event.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(event.description),
            if (event.reward != null) ...[
              const SizedBox(height: 8),
              Text(
                event.reward!,
                style: const TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // Modify location update callback
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
            title: 'Current Position',
            snippet: 'Latitude: ${_currentPosition.latitude}, Longitude: ${_currentPosition.longitude}',
          ),
        ),
      );
      _clearPoints.add(_currentPosition);
    });

    // Check for new event discovery
    _eventService.checkForEvents(_currentPosition);
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
      // Automatically jump to historical point center
      if (_clearPoints.isNotEmpty && _mapController != null) {
        double avgLat = _clearPoints.map((e) => e.latitude).reduce((a, b) => a + b) / _clearPoints.length;
        double avgLng = _clearPoints.map((e) => e.longitude).reduce((a, b) => a + b) / _clearPoints.length;
        _mapController!.animateCamera(CameraUpdate.newLatLng(LatLng(avgLat, avgLng)));
      }
      print('_clearPoints: \n$_clearPoints');
    } catch (e) {
      print('Error loading location points: $e');
    }
  }

  void _onMapCreated(GoogleMapController controller) async {
    _mapController = controller;
    _addMarker(_currentPosition);
    if (_isFamiliarityMode) {
      controller.setMapStyle(_mapStyles[_currentMapStyle]);
    }
    
    // Get initial visible area
    _visibleRegion = await controller.getVisibleRegion();
    
    // 确保地图移动到当前位置
    await _getCurrentLocation();
  }

  void _addMarker(LatLng position) {
    setState(() {
      _markers.clear();
      _markers.add(
        Marker(
          markerId: const MarkerId('current_position'),
          position: position,
          infoWindow: InfoWindow(
            title: 'Current Position',
            snippet: 'Latitude: ${position.latitude}, Longitude: ${position.longitude}',
          ),
        ),
      );
      
      // Record clearing point
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
        print('Search error: $e');
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
    _eventService.removeOnEventDiscoveredListener(_onEventDiscovered);
    super.dispose();
  }

  // Add method to get current location
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
        if (_mapController != null) {
          await _mapController!.animateCamera(
            CameraUpdate.newLatLngZoom(_currentPosition, _currentZoom),
          );
        }

        // 在获取到位置后生成卡片
        _randomCards = _generateRandomCards();
        setState(() {}); // 触发UI更新以显示卡片
      }
    } catch (e) {
      print('Failed to get current location: $e');
    }
  }

  // Load collected cards
  Future<void> _loadCollectedCards() async {
    final cards = await _cardService.getCollectedCards();
    setState(() {
      _collectedCards = cards;
    });
  }

  // Show card dialog
  void _showCardDetails(CardModel card) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(card.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(card.description),
            const SizedBox(height: 8),
            Text(
              'Type: ${card.type}',
              style: const TextStyle(
                color: Colors.blue,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // Collect card
  Future<void> _collectCard(CardModel card) async {
    await _cardService.collectCard(card);
    await _loadCollectedCards();
    setState(() {
      _showCardDialog = false;
    });
  }

  // Generate random cards
  List<CardModel> _generateRandomCards() {
    final List<CardModel> cards = [];
    final Random random = Random();
    final List<String> themes = ['Food', 'Shopping', 'Entertainment', 'Culture', 'Nature', 'History'];
    final List<IconData> icons = [
      Icons.restaurant,
      Icons.shopping_bag,
      Icons.movie,
      Icons.museum,
      Icons.park,
      Icons.history,
    ];

    // Generate cards around user position
    for (int i = 0; i < 15; i++) {
      final themeIndex = random.nextInt(themes.length);
      cards.add(
        CardModel(
          id: DateTime.now().millisecondsSinceEpoch.toString() + i.toString(),
          title: '${themes[themeIndex]} Card',
          description: 'Enjoy special offers at ${themes[themeIndex].toLowerCase()} places',
          type: themes[themeIndex],
          icon: icons[themeIndex],
          color: Colors.primaries[random.nextInt(Colors.primaries.length)],
          position: _calculateRandomPosition(),
        ),
      );
    }

    return cards;
  }

  // Calculate random position
  LatLng _calculateRandomPosition() {
    final Random random = Random();
    // 使用更小的随机范围，使卡片更集中在用户位置附近
    final double latOffset = (random.nextDouble() - 0.5) * 0.002; // 从0.005减小到0.002
    final double lngOffset = (random.nextDouble() - 0.5) * 0.002; // 从0.005减小到0.002
    return LatLng(
      _currentPosition.latitude + latOffset,
      _currentPosition.longitude + lngOffset,
    );
  }

  // 计算两点之间的距离（米）
  double _calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371000; // 地球半径（米）
    final double lat1 = point1.latitude * (pi / 180);
    final double lat2 = point2.latitude * (pi / 180);
    final double dLat = (point2.latitude - point1.latitude) * (pi / 180);
    final double dLng = (point2.longitude - point1.longitude) * (pi / 180);

    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLng / 2) * sin(dLng / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        _mapSize = Size(constraints.maxWidth, constraints.maxHeight);
        
        // Convert all clearing point coordinates
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
                zoom: 22.0,
                tilt: 0,
              ),
              myLocationEnabled: false,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapType: MapType.normal,
              markers: {}, // Do not display Google Maps default Marker
              onCameraMove: (CameraPosition position) async {
                if (_mapController != null && mounted) {
                  _visibleRegion = await _mapController!.getVisibleRegion();
                  setState(() {
                    _currentZoom = position.zoom; // Update current zoom level
                  });
                }
              },
              tiltGesturesEnabled: false, // Disable tilt gestures
              rotateGesturesEnabled: false, // Disable rotation gestures
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
                      zoomLevel: _currentZoom, // Pass current zoom level
                    ),
                    size: _mapSize ?? Size.zero,
                  ),
                ),
              ),
            // Custom red marker and glowing white dot
            if (_mapSize != null && _visibleRegion != null)
              ...[
                // Red marker (character1.png)
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
                // Blue glowing dot (actual position)
                if (_latLngToScreenPoint(_center) != null)
                  Positioned(
                    left: _latLngToScreenPoint(_center)!.dx - 16,
                    top: _latLngToScreenPoint(_center)!.dy - 16,
                    child: _GlowingWhiteDot(),
                  ),
              ],
            // Modify top search bar part, add style selection button
            Positioned(
              top: 60,
              right: 15,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Search bar
                  AnimatedContainer(
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
                    if (_isSearchBarOpen)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 12),
                          child: TextField(
                            controller: _searchController,
                            decoration: const InputDecoration(
                              hintText: 'Search for location...',
                              border: InputBorder.none,
                              isDense: true,
                            ),
                            onSubmitted: _searchPlaces,
                            autofocus: true,
                          ),
                        ),
                      ),
                    IconButton(
                      icon: const Icon(Icons.search, color: Colors.white),
                      onPressed: () {
                        setState(() {
                          if (_isSearchBarOpen) {
                            _searchPlaces(_searchController.text);
                          }
                          _isSearchBarOpen = !_isSearchBarOpen;
                        });
                      },
                      tooltip: 'Search',
                    ),
                  ],
                ),
                  ),
                  // Style selection button
                  const SizedBox(height: 10),
                  Container(
                    width: 56,
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
                    child: PopupMenuButton<String>(
                      icon: const Icon(Icons.palette, color: Colors.white),
                      tooltip: 'Select map style',
                      onSelected: _changeMapStyle,
                      itemBuilder: (BuildContext context) {
                        return _mapStyles.keys.map((String styleName) {
                          return PopupMenuItem<String>(
                            value: styleName,
                            child: Row(
                              children: [
                                if (_currentMapStyle == styleName)
                                  const Icon(Icons.check, size: 18),
                                if (_currentMapStyle == styleName)
                                  const SizedBox(width: 8),
                                Text(styleName),
                              ],
                            ),
                          );
                        }).toList();
                      },
                    ),
                  ),
                ],
              ),
            ),
            // Add familiarity switch button
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
                    // Location tracking switch
                    IconButton(
                      icon: Icon(
                        _isTracking ? Icons.location_on : Icons.location_off,
                        color: Colors.white,
                      ),
                      onPressed: _toggleTracking,
                      tooltip: _isTracking ? 'Stop location tracking' : 'Start location tracking',
                    ),
                    // Familiarity display switch
                    IconButton(
                      icon: Icon(
                        _isFamiliarityMode ? Icons.visibility : Icons.visibility_off,
                        color: Colors.white,
                      ),
                      onPressed: () {
                        setState(() {
                          _isFamiliarityMode = !_isFamiliarityMode;
                          if (_isFamiliarityMode) {
                            _mapController?.setMapStyle(_mapStyles[_currentMapStyle]);
                          } else {
                            _mapController?.setMapStyle(null);
                          }
                        });
                      },
                      tooltip: _isFamiliarityMode ? 'Hide familiarity' : 'Show familiarity',
                    ),
                  ],
                ),
              ),
            ),
            // Add zoom control button
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
                    // Zoom in button
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
                      tooltip: 'Zoom in',
                    ),
                    // Zoom out button
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
                      tooltip: 'Zoom out',
                    ),
                  ],
                ),
              ),
            ),
            // Add location button
            Positioned(
              bottom: 120, // Bottom position
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
                        CameraUpdate.newLatLngZoom(_currentPosition, 17.0),
                      );
                    }
                  },
                ),
              ),
            ),
            // Add movement controller and placement button
            Positioned(
              left: 20,
              bottom: 120,
              child: JoystickController(
                onDirectionChanged: _onJoystickDirectionChanged,
              ),
            ),
            // Placement mode button
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
            // Add event dialog
            if (_showEventDialog && _currentEvent != null)
              Positioned.fill(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _showEventDialog = false;
                    });
                    _showEventDetails(_currentEvent!);
                  },
                  child: Container(
                    color: Colors.black.withOpacity(0.5),
                    child: Center(
                      child: Container(
                        margin: const EdgeInsets.all(20),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 10,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _currentEvent!.title,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(_currentEvent!.description),
                            if (_currentEvent!.reward != null) ...[
                              const SizedBox(height: 10),
                              Text(
                                _currentEvent!.reward!,
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                            const SizedBox(height: 20),
                            const Text(
                              'Click to view details',
                              style: TextStyle(
                                color: Colors.blue,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            // Add event icon
            if (_mapSize != null && _visibleRegion != null)
              ..._eventService.getUndiscoveredEvents().map((event) {
                final screenPoint = _latLngToScreenPoint(event.position);
                if (screenPoint == null) return const SizedBox.shrink();
                
                final distance = _eventService.calculateDistance(_currentPosition, event.position);
                final opacity = event.calculateOpacity(distance);
                final size = event.calculateSize(distance);
                
                if (opacity <= 0 || size <= 0) return const SizedBox.shrink();
                
                return Positioned(
                  left: screenPoint.dx - size / 2,
                  top: screenPoint.dy - size / 2,
                  child: Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      color: event.color.withOpacity(opacity * 0.2),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: event.color.withOpacity(opacity * 0.3),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        event.icon,
                        color: event.color.withOpacity(opacity),
                        size: size * 0.6,
                      ),
                    ),
                  ),
                );
              }).toList(),
            // Add random cards
            if (_isFamiliarityMode && _currentZoom >= 17.0) // 只有在熟悉度模式下且缩放>=17才显示卡片
              ..._randomCards.map((card) {
                final screenPoint = _latLngToScreenPoint(card.position);
                if (screenPoint == null) return const SizedBox.shrink();
                
                // 计算卡片与角色的距离
                final distance = _calculateDistance(_currentPosition, card.position);
                // 设置激活距离为10米
                final isActive = distance <= 10.0;
                // 根据距离计算透明度
                final opacity = isActive ? 0.8 : 0.3;
                
                return Positioned(
                  left: screenPoint.dx - 24,
                  top: screenPoint.dy - 24,
                  child: GestureDetector(
                    onTap: isActive ? () {
                      setState(() {
                        _currentCard = card;
                        _showCardDialog = true;
                      });
                    } : null,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: isActive ? card.color.withOpacity(opacity) : Colors.grey.withOpacity(opacity),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: isActive ? card.color.withOpacity(0.3) : Colors.grey.withOpacity(0.3),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          card.icon,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            // Add card dialog
            if (_showCardDialog && _currentCard != null)
              Positioned.fill(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _showCardDialog = false;
                    });
                    _collectCard(_currentCard!);
                  },
                  child: Container(
                    color: Colors.black.withOpacity(0.5),
                    child: Center(
                      child: Container(
                        margin: const EdgeInsets.all(20),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 10,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _currentCard!.icon,
                              size: 48,
                              color: _currentCard!.color,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _currentCard!.title,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(_currentCard!.description),
                            const SizedBox(height: 20),
                            const Text(
                              'Click to collect card',
                              style: TextStyle(
                                color: Colors.blue,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// Modify glowing white dot component
class _GlowingWhiteDot extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24, // Reduce overall size
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.white.withOpacity(0.5), // Glow weaker
            blurRadius: 8, // Spread range smaller
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