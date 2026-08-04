import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:dio/dio.dart';

class OrderTrackingScreen extends StatefulWidget {
  final Map<String, dynamic> order;
  const OrderTrackingScreen({super.key, required this.order});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  // Map Controllers
  late MapController _mapController;
  
  // Real tracking data
  List<Map<String, dynamic>> _trackingHistory = [];
  bool _isLoading = true;
  bool _isLoadingMap = true;
  bool _routeCalculated = false;
  bool _mapReady = false;
  
  // Location data
  LatLng? _currentLocation;
  LatLng? _destinationLocation;
  List<LatLng> _routePoints = [];
  String _routeStatus = 'Calculating route...';
  
  // Mock location for demo
  final List<Map<String, dynamic>> _mockTrackingLocations = [
    {'status': 'Order Placed', 'lat': 4.0511, 'lng': 9.7679, 'time': '09:00 AM', 'date': '2024-01-15', 'location': 'Warehouse A'},
    {'status': 'Processing', 'lat': 4.0525, 'lng': 9.7600, 'time': '10:30 AM', 'date': '2024-01-15', 'location': 'Processing Center'},
    {'status': 'Shipped', 'lat': 4.0450, 'lng': 9.7550, 'time': '02:00 PM', 'date': '2024-01-15', 'location': 'Transit'},
    {'status': 'Out for Delivery', 'lat': 4.0350, 'lng': 9.7450, 'time': '08:00 AM', 'date': '2024-01-16', 'location': 'Near your location'},
    {'status': 'Delivered', 'lat': 4.0250, 'lng': 9.7350, 'time': '10:30 AM', 'date': '2024-01-16', 'location': 'Your address'},
  ];

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _animationController.forward();
    
    _initializeTrackingData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _initializeTrackingData() async {
    setState(() => _isLoading = true);
    
    try {
      await _fetchTrackingDataFromDatabase();
      await _initializeMapLocations();
      await _calculateRoute();
      setState(() => _isLoading = false);
    } catch (e) {
      print('Error initializing tracking: $e');
      _trackingHistory = _mockTrackingLocations;
      await _initializeMapLocations();
      await _calculateRoute();
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchTrackingDataFromDatabase() async {
    try {
      // Check if tracking_data exists in the order
      if (widget.order['tracking_data'] != null) {
        final trackingData = widget.order['tracking_data'] as List;
        if (trackingData.isNotEmpty) {
          _trackingHistory = List<Map<String, dynamic>>.from(trackingData);
          
          // Update status from tracking data
          final latest = _trackingHistory.last;
          if (latest['status'] != null) {
            widget.order['status'] = latest['status'];
          }
        } else {
          _trackingHistory = _mockTrackingLocations;
        }
      } else {
        // Check for tracking_updates table data
        try {
          final response = await Supabase.instance.client
              .from('tracking_updates')
              .select()
              .eq('order_id', widget.order['id'])
              .order('created_at', ascending: true);
          
          if (response.isNotEmpty) {
            _trackingHistory = List<Map<String, dynamic>>.from(response).map((update) {
              return {
                'status': update['status'] ?? 'In Transit',
                'lat': update['lat'] ?? 4.0511,
                'lng': update['lng'] ?? 9.7679,
                'time': _formatTime(update['created_at']),
                'date': _formatDate(update['created_at']),
                'location': update['location_name'] ?? 'In Transit',
              };
            }).toList();
          } else {
            _trackingHistory = _mockTrackingLocations;
          }
        } catch (e) {
          print('Error fetching from tracking_updates: $e');
          _trackingHistory = _mockTrackingLocations;
        }
      }
      
      // Get latest tracking entry
      final latestTracking = _trackingHistory.isNotEmpty 
          ? _trackingHistory.last 
          : _mockTrackingLocations.last;
      
      // Set current location (Admin's updated location)
      if (latestTracking['lat'] != null && latestTracking['lng'] != null) {
        _currentLocation = LatLng(
          latestTracking['lat'].toDouble(),
          latestTracking['lng'].toDouble(),
        );
        print('📍 Current Package Location: ${_currentLocation!.latitude}, ${_currentLocation!.longitude}');
      }
      
      // Set destination location (Customer's delivery address)
      if (widget.order['customer_lat'] != null && widget.order['customer_lng'] != null) {
        _destinationLocation = LatLng(
          widget.order['customer_lat'].toDouble(),
          widget.order['customer_lng'].toDouble(),
        );
        print('📍 Destination Location: ${_destinationLocation!.latitude}, ${_destinationLocation!.longitude}');
      } else {
        // Find delivered location from tracking history
        final delivered = _trackingHistory.firstWhere(
          (track) => track['status'] == 'Delivered',
          orElse: () => _trackingHistory.isNotEmpty ? _trackingHistory.last : _mockTrackingLocations.last,
        );
        if (delivered['lat'] != null && delivered['lng'] != null) {
          _destinationLocation = LatLng(
            delivered['lat'].toDouble(),
            delivered['lng'].toDouble(),
          );
          print('📍 Destination Location (from tracking): ${_destinationLocation!.latitude}, ${_destinationLocation!.longitude}');
        }
      }
    } catch (e) {
      print('Error fetching tracking data: $e');
      _trackingHistory = _mockTrackingLocations;
      rethrow;
    }
  }

  // Helper method to format time
  String _formatTime(String? dateTimeString) {
    if (dateTimeString == null) return 'N/A';
    try {
      final dateTime = DateTime.parse(dateTimeString);
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'N/A';
    }
  }

  // Helper method to format date
  String _formatDate(String? dateTimeString) {
    if (dateTimeString == null) return 'N/A';
    try {
      final dateTime = DateTime.parse(dateTimeString);
      return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'N/A';
    }
  }

  Future<void> _initializeMapLocations() async {
    _currentLocation ??= const LatLng(4.0511, 9.7679);
    _destinationLocation ??= const LatLng(4.0250, 9.7350);
    
    print('📍 Final Current Location: ${_currentLocation!.latitude}, ${_currentLocation!.longitude}');
    print('📍 Final Destination Location: ${_destinationLocation!.latitude}, ${_destinationLocation!.longitude}');
  }

  Future<void> _calculateRoute() async {
    if (_currentLocation == null || _destinationLocation == null) {
      print('❌ Cannot calculate route: missing locations');
      setState(() {
        _routePoints = [];
        _isLoadingMap = false;
        _routeCalculated = false;
        _routeStatus = 'Missing location data';
      });
      return;
    }
    
    setState(() {
      _isLoadingMap = true;
      _routeStatus = 'Calculating route...';
    });
    
    try {
      // Generate route points - using multiple methods
      await _generateRoutePoints();
      
      if (_routePoints.isEmpty) {
        print('⚠️ No route points generated, using direct line');
        _generateDirectRoute();
      }
      
      setState(() {
        _routeCalculated = true;
        _routeStatus = 'Route ready (${_routePoints.length} points)';
      });
      
      print('✅ Route generated with ${_routePoints.length} points');
      
    } catch (e) {
      print('❌ Error calculating route: $e');
      _generateDirectRoute();
      setState(() {
        _routeCalculated = true;
        _routeStatus = 'Using direct route';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoadingMap = false);
      }
    }
  }

  Future<void> _generateRoutePoints() async {
    final dio = Dio();
    dio.options.connectTimeout = const Duration(seconds: 10);
    dio.options.receiveTimeout = const Duration(seconds: 10);
    
    // Try OSRM API
    try {
      final url = 'https://router.project-osrm.org/route/v1/driving/'
          '${_currentLocation!.longitude},${_currentLocation!.latitude};'
          '${_destinationLocation!.longitude},${_destinationLocation!.latitude}'
          '?overview=full&geometries=geojson';
      
      print('🌐 Trying OSRM: $url');
      final response = await dio.get(url);
      
      if (response.statusCode == 200) {
        final data = response.data;
        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final geometry = route['geometry'];
          
          if (geometry != null && geometry['coordinates'] != null) {
            final coords = geometry['coordinates'] as List;
            print('✅ OSRM route has ${coords.length} points');
            
            if (coords.length > 1) {
              final points = coords.map((coord) {
                return LatLng(coord[1].toDouble(), coord[0].toDouble());
              }).toList();
              
              setState(() {
                _routePoints = points;
              });
              return;
            }
          }
        }
      }
    } catch (e) {
      print('⚠️ OSRM failed: $e');
    }
    
    // Try GraphHopper as fallback
    try {
      final url = 'https://graphhopper.com/api/1/route'
          '?point=${_currentLocation!.latitude},${_currentLocation!.longitude}'
          '&point=${_destinationLocation!.latitude},${_destinationLocation!.longitude}'
          '&vehicle=car&key=1a2b3c4d5e6f7g8h9i0j';
      
      print('🌐 Trying GraphHopper: $url');
      final response = await dio.get(url);
      
      if (response.statusCode == 200) {
        final data = response.data;
        if (data['paths'] != null && data['paths'].isNotEmpty) {
          final path = data['paths'][0];
          final points = path['points'];
          
          if (points != null && points['coordinates'] != null) {
            final coords = points['coordinates'] as List;
            print('✅ GraphHopper route has ${coords.length} points');
            
            if (coords.length > 1) {
              final routePoints = coords.map((coord) {
                return LatLng(coord[1].toDouble(), coord[0].toDouble());
              }).toList();
              
              setState(() {
                _routePoints = routePoints;
              });
              return;
            }
          }
        }
      }
    } catch (e) {
      print('⚠️ GraphHopper failed: $e');
    }
  }

  void _generateDirectRoute() {
    if (_currentLocation == null || _destinationLocation == null) return;
    
    // Create a direct route with multiple points for a smooth line
    final List<LatLng> points = [];
    final lat1 = _currentLocation!.latitude;
    final lon1 = _currentLocation!.longitude;
    final lat2 = _destinationLocation!.latitude;
    final lon2 = _destinationLocation!.longitude;
    
    // Generate 20 points along the direct path
    for (int i = 0; i <= 20; i++) {
      final fraction = i / 20;
      final lat = lat1 + (lat2 - lat1) * fraction;
      final lon = lon1 + (lon2 - lon1) * fraction;
      points.add(LatLng(lat, lon));
    }
    
    setState(() {
      _routePoints = points;
    });
    print('📍 Direct route generated with ${points.length} points');
  }

  void _fitMapToRoute() {
    if (_routePoints.isEmpty || !mounted) return;
    
    try {
      // Calculate bounds of the route
      double minLat = _routePoints.first.latitude;
      double maxLat = _routePoints.first.latitude;
      double minLng = _routePoints.first.longitude;
      double maxLng = _routePoints.first.longitude;
      
      for (var point in _routePoints) {
        if (point.latitude < minLat) minLat = point.latitude;
        if (point.latitude > maxLat) maxLat = point.latitude;
        if (point.longitude < minLng) minLng = point.longitude;
        if (point.longitude > maxLng) maxLng = point.longitude;
      }
      
      // Add padding
      final latPadding = (maxLat - minLat) * 0.3 + 0.02;
      final lngPadding = (maxLng - minLng) * 0.3 + 0.02;
      
      final center = LatLng(
        (minLat + maxLat) / 2,
        (minLng + maxLng) / 2,
      );
      
      // Calculate zoom level
      final latDiff = maxLat - minLat + latPadding * 2;
      final lngDiff = maxLng - minLng + lngPadding * 2;
      final maxDiff = latDiff > lngDiff ? latDiff : lngDiff;
      double zoom = 12 - (maxDiff * 40);
      zoom = zoom.clamp(10, 15);
      
      _mapController.move(center, zoom);
      print('🗺️ Map fitted to route: center=$center, zoom=$zoom');
    } catch (e) {
      print('⚠️ Error fitting map: $e');
    }
  }

  int _getStatusIndex(String status) {
    final statusMap = {
      'pending': 0,
      'processing': 1,
      'paid': 2,
      'shipped': 3,
      'delivered': 4,
    };
    return statusMap[status] ?? 0;
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending': return Colors.orange;
      case 'processing': return Colors.blue;
      case 'paid': return Colors.green;
      case 'shipped': return Colors.purple;
      case 'delivered': return Colors.teal;
      case 'cancelled': return Colors.red;
      default: return Colors.grey;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'pending': return 'Pending';
      case 'processing': return 'Processing';
      case 'paid': return 'Paid';
      case 'shipped': return 'Shipped';
      case 'delivered': return 'Delivered';
      case 'cancelled': return 'Cancelled';
      default: return status;
    }
  }

  String _formatCurrency(dynamic amount) {
    if (amount == null) return '0 XAF';
    try {
      return '${amount.toStringAsFixed(0)} XAF';
    } catch (e) {
      return '0 XAF';
    }
  }

  // Calculate distance between two coordinates in kilometers
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371;
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLon = (lon2 - lon1) * math.pi / 180;
    final a = 
        (dLat / 2) * (dLat / 2) +
        math.cos(lat1 * math.pi / 180) * 
        math.cos(lat2 * math.pi / 180) * 
        (dLon / 2) * (dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isMobile = MediaQuery.of(context).size.width < 600;
    final statusColor = _getStatusColor(widget.order['status'] ?? 'pending');

    return Scaffold(
      backgroundColor: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          'Track Order',
          style: TextStyle(
            fontSize: isMobile ? 16 : 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: isDark ? Colors.grey.shade800 : Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: isDark ? Colors.white : Colors.grey.shade700),
            onPressed: _initializeTrackingData,
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: SpinKitFadingGrid(
                color: Colors.blue.shade700,
                size: 50,
              ),
            )
          : FadeTransition(
              opacity: _fadeAnimation,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Order Info
                    _buildOrderInfoCard(isDark, isMobile, statusColor),
                    const SizedBox(height: 16),

                    // Live Map with Route
                    _buildLiveMap(isDark),
                    const SizedBox(height: 16),

                    // Route Info
                    _buildRouteInfo(isDark),
                    const SizedBox(height: 16),

                    // Live Tracking Status
                    _buildLiveTrackingStatus(isDark, statusColor),
                    const SizedBox(height: 16),

                    // Tracking Timeline
                    _buildTrackingTimeline(isDark),
                    const SizedBox(height: 16),

                    // Order Items
                    if (widget.order['products'] != null)
                      _buildOrderItems(isDark),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildOrderInfoCard(bool isDark, bool isMobile, Color statusColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Order #${widget.order['order_number'] ?? 'N/A'}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: isMobile ? 16 : 18,
                  color: isDark ? Colors.white : Colors.grey.shade900,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _getStatusLabel(widget.order['status'] ?? 'pending').toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Amount',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatCurrency(widget.order['total_amount']),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ],
              ),
              if (widget.order['tracking_number'] != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Tracking Number',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.order['tracking_number'],
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLiveMap(bool isDark) {
    return Container(
      height: 350,
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: _isLoadingMap
            ? Center(
                child: SpinKitFadingCircle(
                  color: Colors.blue.shade700,
                  size: 40,
                ),
              )
            : FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _currentLocation ?? const LatLng(4.0511, 9.7679),
                  initialZoom: 13,
                  onMapReady: () {
                    print('🗺️ Map is ready!');
                    setState(() => _mapReady = true);
                    if (_routePoints.isNotEmpty) {
                      Future.delayed(const Duration(milliseconds: 500), () {
                        _fitMapToRoute();
                      });
                    }
                  },
                ),
                children: [
                  // Background tiles
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.yourcompany.app',
                    additionalOptions: const {
                      'attribution': '© OpenStreetMap contributors',
                    },
                  ),
                  
                  // ✅ ROUTE POLYLINE - This is what shows the route!
                  if (_routePoints.isNotEmpty && _routePoints.length >= 2)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: _routePoints,
                          color: Colors.blue.shade700,
                          strokeWidth: 6.0,
                          borderColor: Colors.blue.shade100,
                          borderStrokeWidth: 2.0,
                        ),
                      ],
                    ),
                  
                  // Markers
                  MarkerLayer(
                    markers: [
                      // START: Package Location (Admin updated)
                      if (_currentLocation != null)
                        Marker(
                          point: _currentLocation!,
                          width: 60,
                          height: 60,
                          alignment: Alignment.center,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: Colors.red.shade600,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 3),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.red.withOpacity(0.5),
                                      blurRadius: 15,
                                      spreadRadius: 5,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.local_shipping,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                              Positioned(
                                bottom: -22,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.8),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    '📦 Package',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      
                      // END: Destination (Customer)
                      if (_destinationLocation != null)
                        Marker(
                          point: _destinationLocation!,
                          width: 60,
                          height: 60,
                          alignment: Alignment.center,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: Colors.green.shade600,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 3),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.green.withOpacity(0.5),
                                      blurRadius: 15,
                                      spreadRadius: 5,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.location_on,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                              Positioned(
                                bottom: -22,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.8),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    '📍 Delivery',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  
                  // Attribution
                  RichAttributionWidget(
                    attributions: [
                      TextSourceAttribution(
                        '© OpenStreetMap',
                        onTap: () {},
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildRouteInfo(bool isDark) {
    // Calculate approximate distance
    String distance = 'Calculating...';
    if (_currentLocation != null && _destinationLocation != null) {
      final dist = _calculateDistance(
        _currentLocation!.latitude,
        _currentLocation!.longitude,
        _destinationLocation!.latitude,
        _destinationLocation!.longitude,
      );
      distance = '${dist.toStringAsFixed(1)} km';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.route, color: Colors.blue.shade700, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Route Status',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.grey.shade900,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '$_routeStatus • Distance: $distance',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
                Text(
                  'From: ${_currentLocation?.latitude.toStringAsFixed(4)}, ${_currentLocation?.longitude.toStringAsFixed(4)}',
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                  ),
                ),
                Text(
                  'To: ${_destinationLocation?.latitude.toStringAsFixed(4)}, ${_destinationLocation?.longitude.toStringAsFixed(4)}',
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _routePoints.isNotEmpty 
                  ? Colors.green.withOpacity(0.1) 
                  : Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _routePoints.isNotEmpty ? Colors.green : Colors.orange,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  _routePoints.isNotEmpty ? 'Active' : 'Pending',
                  style: TextStyle(
                    fontSize: 10,
                    color: _routePoints.isNotEmpty 
                        ? Colors.green.shade700 
                        : Colors.orange.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveTrackingStatus(bool isDark, Color statusColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.live_help, color: Colors.green),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Live Tracking',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.grey.shade900,
                  ),
                ),
                Text(
                  'Package is ${_getStatusLabel(widget.order['status'] ?? 'pending').toLowerCase()}',
                  style: TextStyle(
                    fontSize: 12,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              children: [
                Icon(Icons.circle, color: Colors.green, size: 8),
                SizedBox(width: 4),
                Text(
                  'Live',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackingTimeline(bool isDark) {
    final currentStatus = _getStatusIndex(widget.order['status'] ?? 'pending');
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tracking History',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.grey.shade900,
            ),
          ),
          const SizedBox(height: 16),
          ...List.generate(_trackingHistory.length, (index) {
            final location = _trackingHistory[index];
            final isCompleted = index <= currentStatus;
            final isCurrent = index == currentStatus;
            final hasLine = index < _trackingHistory.length - 1;
            
            return _buildTimelineItem(
              title: location['status'] ?? 'In Transit',
              time: location['time'] ?? 'N/A',
              date: location['date'] ?? 'N/A',
              location: location['location'] ?? 'In Transit',
              isCompleted: isCompleted,
              isCurrent: isCurrent,
              hasLine: hasLine,
              isDark: isDark,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTimelineItem({
    required String title,
    required String time,
    required String date,
    required String location,
    required bool isCompleted,
    required bool isCurrent,
    required bool hasLine,
    required bool isDark,
  }) {
    final color = isCompleted ? Colors.green : (isDark ? Colors.grey.shade600 : Colors.grey.shade400);
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 32,
          child: Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isCompleted ? color.withOpacity(0.2) : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isCompleted ? color : (isDark ? Colors.grey.shade600 : Colors.grey.shade400),
                    width: isCurrent ? 3 : 2,
                  ),
                ),
                child: Icon(
                  isCompleted ? Icons.check : Icons.circle,
                  color: isCompleted ? color : (isDark ? Colors.grey.shade600 : Colors.grey.shade400),
                  size: 16,
                ),
              ),
              if (hasLine)
                Container(
                  width: 2,
                  height: 40,
                  color: isCompleted ? Colors.green : (isDark ? Colors.grey.shade700 : Colors.grey.shade300),
                ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: hasLine ? 0 : 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                        color: isCompleted 
                            ? (isDark ? Colors.white : Colors.grey.shade900)
                            : (isDark ? Colors.grey.shade500 : Colors.grey.shade500),
                      ),
                    ),
                    if (isCurrent)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Current',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                Text(
                  '$time - $date',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
                Text(
                  location,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOrderItems(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Order Items',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.grey.shade900,
            ),
          ),
          const SizedBox(height: 12),
          ...(widget.order['products'] as List).map((item) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${item['quantity'] ?? 1}x ${item['product_name'] ?? 'Product'}',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                      ),
                    ),
                  ),
                  Text(
                    '${(item['price'] ?? 0) * (item['quantity'] ?? 1)} XAF',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.grey.shade900,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}