// admin_order_tracking.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:dio/dio.dart';

class AdminOrderTrackingScreen extends StatefulWidget {
  final Map<String, dynamic> order;
  const AdminOrderTrackingScreen({super.key, required this.order});

  @override
  State<AdminOrderTrackingScreen> createState() => _AdminOrderTrackingScreenState();
}

class _AdminOrderTrackingScreenState extends State<AdminOrderTrackingScreen> with SingleTickerProviderStateMixin {
  late Map<String, dynamic> _order;
  bool _isLoading = false;
  bool _isUpdatingLocation = false;
  bool _isGeneratingTracking = false;
  bool _isLoadingMap = true;
  bool _mapReady = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final TextEditingController _trackingController = TextEditingController();
  final TextEditingController _locationLatController = TextEditingController();
  final TextEditingController _locationLngController = TextEditingController();
  final TextEditingController _locationNameController = TextEditingController();
  
  // Map Controllers
  late MapController _mapController;
  
  // Location data
  LatLng? _currentLocation;
  LatLng? _destinationLocation;
  LatLng? _companyLocation;
  List<LatLng> _routePoints = [];
  List<Map<String, dynamic>> _trackingHistory = [];
  String _routeStatus = 'Calculating...';
  
  // Current status
  String _currentStatus = 'pending';
  
  // Default company location (CHANGE THIS TO YOUR COMPANY COORDINATES)
  final LatLng _defaultCompanyLocation = const LatLng(4.0511, 9.7679); // Douala, Cameroon
  
  final List<String> _statusOptions = [
    'pending',
    'processing', 
    'paid', 
    'shipped', 
    'delivered', 
    'cancelled'
  ];

  @override
  void initState() {
    super.initState();
    _order = widget.order;
    _currentStatus = _order['status'] ?? 'pending';
    _mapController = MapController();
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _animationController.forward();
    
    if (_order['tracking_number'] != null) {
      _trackingController.text = _order['tracking_number'].toString();
    }
    
    _companyLocation = _defaultCompanyLocation;
    
    _initializeTrackingData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _trackingController.dispose();
    _locationLatController.dispose();
    _locationLngController.dispose();
    _locationNameController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _initializeTrackingData() async {
    setState(() => _isLoadingMap = true);
    
    try {
      // Safe access to tracking_data
      if (_order.containsKey('tracking_data') && _order['tracking_data'] != null) {
        final trackingData = _order['tracking_data'];
        if (trackingData is List && trackingData.isNotEmpty) {
          _trackingHistory = List<Map<String, dynamic>>.from(trackingData);
        } else {
          _trackingHistory = _getDefaultTrackingHistory();
        }
      } else {
        _trackingHistory = _getDefaultTrackingHistory();
      }
      
      // Set company location as start
      _currentLocation = _companyLocation;
      print('📍 Company Location: ${_currentLocation!.latitude}, ${_currentLocation!.longitude}');
      
      // Determine destination from order or tracking history
      LatLng? dest;
      
      // 1. Check if order has customer location (admin-updated)
      if (_order.containsKey('customer_lat') && _order['customer_lat'] != null &&
          _order.containsKey('customer_lng') && _order['customer_lng'] != null) {
        try {
          final lat = double.tryParse(_order['customer_lat'].toString()) ?? 
                       (_order['customer_lat'] as num?)?.toDouble();
          final lng = double.tryParse(_order['customer_lng'].toString()) ?? 
                       (_order['customer_lng'] as num?)?.toDouble();
          if (lat != null && lng != null) {
            dest = LatLng(lat, lng);
            print('📍 Destination from order: $dest');
          }
        } catch (e) {
          print('Error parsing customer location: $e');
        }
      }
      
      // 2. If not found, use latest tracking entry
      if (dest == null && _trackingHistory.isNotEmpty) {
        final latest = _trackingHistory.last;
        if (latest.containsKey('lat') && latest['lat'] != null &&
            latest.containsKey('lng') && latest['lng'] != null) {
          try {
            final lat = double.tryParse(latest['lat'].toString()) ?? 
                         (latest['lat'] as num?)?.toDouble();
            final lng = double.tryParse(latest['lng'].toString()) ?? 
                         (latest['lng'] as num?)?.toDouble();
            if (lat != null && lng != null) {
              dest = LatLng(lat, lng);
              print('📍 Destination from tracking: $dest');
            }
          } catch (e) {
            print('Error parsing tracking location: $e');
          }
        }
      }
      
      // 3. Fallback to a default location
      if (dest == null) {
        dest = const LatLng(4.0250, 9.7350);
        print('📍 Using default destination: $dest');
      }
      
      _destinationLocation = dest;
      
      // Calculate route from company to destination
      await _calculateRoute();
      
    } catch (e) {
      print('❌ Error initializing tracking: $e');
      setState(() {
        _routeStatus = 'Error: $e';
        _routePoints = [];
      });
      // Set default locations to avoid crash
      _currentLocation ??= _companyLocation;
      _destinationLocation ??= const LatLng(4.0250, 9.7350);
    } finally {
      setState(() => _isLoadingMap = false);
    }
  }

  List<Map<String, dynamic>> _getDefaultTrackingHistory() {
    return [
      {
        'status': 'Order Placed',
        'lat': 4.0511,
        'lng': 9.7679,
        'time': DateTime.now().subtract(const Duration(hours: 5)).toIso8601String(),
        'location': 'Warehouse A'
      },
    ];
  }

  Future<void> _calculateRoute() async {
    if (_currentLocation == null || _destinationLocation == null) {
      print('❌ Cannot calculate route: missing locations');
      setState(() {
        _routePoints = [];
        _routeStatus = 'Missing locations';
        _isLoadingMap = false;
      });
      return;
    }
    
    // Check if locations are too close
    final latDiff = (_currentLocation!.latitude - _destinationLocation!.latitude).abs();
    final lngDiff = (_currentLocation!.longitude - _destinationLocation!.longitude).abs();
    
    if (latDiff < 0.0001 && lngDiff < 0.0001) {
      print('⚠️ Locations are too close - using direct route');
      setState(() {
        _routeStatus = 'Locations too close - using direct line';
      });
      _generateDirectRoute();
      return;
    }
    
    setState(() {
      _routeStatus = 'Calculating route...';
      _isLoadingMap = true;
    });
    
    try {
      final dio = Dio();
      final url = 'https://router.project-osrm.org/route/v1/driving/'
          '${_currentLocation!.longitude},${_currentLocation!.latitude};'
          '${_destinationLocation!.longitude},${_destinationLocation!.latitude}'
          '?overview=full&geometries=geojson';
      
      print('🌐 Route URL: $url');
      
      final response = await dio.get(url);
      
      if (response.statusCode == 200) {
        final data = response.data;
        print('✅ Route response received');
        
        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final geometry = route['geometry'];
          
          if (geometry != null && geometry['coordinates'] != null) {
            final coords = geometry['coordinates'] as List;
            print('✅ Route has ${coords.length} points');
            
            if (coords.length > 1) {
              setState(() {
                _routePoints = coords.map((coord) {
                  return LatLng(coord[1].toDouble(), coord[0].toDouble());
                }).toList();
                _routeStatus = 'Route ready (${_routePoints.length} points)';
                _isLoadingMap = false;
              });
              print('✅ Route points set: ${_routePoints.length}');
              
              // Auto-fit map after route is calculated
              Future.delayed(const Duration(milliseconds: 300), () {
                if (_routePoints.isNotEmpty) {
                  _fitMapToRoute();
                }
              });
              return;
            }
          }
        }
        // If we get here, no valid route found
        _generateDirectRoute();
      } else {
        print('⚠️ Route API error: ${response.statusCode}');
        _generateDirectRoute();
      }
    } catch (e) {
      print('❌ Error calculating route: $e');
      _generateDirectRoute();
    } finally {
      setState(() => _isLoadingMap = false);
    }
  }

  void _generateDirectRoute() {
    if (_currentLocation == null || _destinationLocation == null) return;
    
    print('📍 Generating direct route...');
    
    final List<LatLng> points = [];
    final lat1 = _currentLocation!.latitude;
    final lon1 = _currentLocation!.longitude;
    final lat2 = _destinationLocation!.latitude;
    final lon2 = _destinationLocation!.longitude;
    
    for (int i = 0; i <= 20; i++) {
      final fraction = i / 20;
      final lat = lat1 + (lat2 - lat1) * fraction;
      final lon = lon1 + (lon2 - lon1) * fraction;
      points.add(LatLng(lat, lon));
    }
    
    setState(() {
      _routePoints = points;
      _routeStatus = 'Direct route (${points.length} points)';
      _isLoadingMap = false;
    });
    print('✅ Direct route generated with ${points.length} points');
    
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_routePoints.isNotEmpty) {
        _fitMapToRoute();
      }
    });
  }

  void _fitMapToRoute() {
    if (_routePoints.isEmpty || !mounted) return;
    
    try {
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
      
      final latPadding = (maxLat - minLat) * 0.3 + 0.02;
      final lngPadding = (maxLng - minLng) * 0.3 + 0.02;
      
      final center = LatLng(
        (minLat + maxLat) / 2,
        (minLng + maxLng) / 2,
      );
      
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

  Future<void> _updatePackageLocation() async {
    final latText = _locationLatController.text.trim();
    final lngText = _locationLngController.text.trim();
    final locationName = _locationNameController.text.trim();
    
    if (latText.isEmpty || lngText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter both latitude and longitude'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    try {
      final lat = double.parse(latText);
      final lng = double.parse(lngText);
      
      setState(() {
        _isUpdatingLocation = true;
        _destinationLocation = LatLng(lat, lng);
      });
      
      final newTrackingEntry = {
        'status': _currentStatus,
        'lat': lat,
        'lng': lng,
        'time': DateTime.now().toIso8601String(),
        'location': locationName.isNotEmpty ? locationName : 'In Transit',
      };
      
      _trackingHistory.add(newTrackingEntry);
      
      final updateData = {
        'tracking_data': _trackingHistory,
        'updated_at': DateTime.now().toIso8601String(),
        'current_lat': lat,
        'current_lng': lng,
        'last_location_update': DateTime.now().toIso8601String(),
        'customer_lat': lat,
        'customer_lng': lng,
      };
      
      if (_currentStatus == 'paid' && _order['tracking_number'] == null) {
        updateData['status'] = 'shipped';
        final trackingNumber = 'TRK-${DateTime.now().year}-${DateTime.now().millisecondsSinceEpoch.toString().substring(0, 6)}';
        updateData['tracking_number'] = trackingNumber;
        _order['tracking_number'] = trackingNumber;
        _order['status'] = 'shipped';
        _currentStatus = 'shipped';
      }
      
      await Supabase.instance.client
          .from('orders')
          .update(updateData)
          .eq('id', _order['id']);
      
      setState(() {
        _order['tracking_data'] = _trackingHistory;
        _order['current_lat'] = lat;
        _order['current_lng'] = lng;
        _order['customer_lat'] = lat;
        _order['customer_lng'] = lng;
        _isUpdatingLocation = false;
      });
      
      // Recalculate route from company to new location
      _currentLocation = _companyLocation;
      await _calculateRoute();
      
      _locationLatController.clear();
      _locationLngController.clear();
      _locationNameController.clear();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _order['tracking_number'] != null && _order['status'] == 'shipped'
                ? 'Package location updated and shipped! Tracking #: ${_order['tracking_number']}'
                : 'Package location updated successfully! Customer can now see it.'
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
      
    } catch (e) {
      setState(() => _isUpdatingLocation = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _updateOrderStatus(String newStatus) async {
    setState(() => _isLoading = true);

    try {
      await Supabase.instance.client
          .from('orders')
          .update({
            'status': newStatus,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', _order['id']);

      setState(() {
        _order['status'] = newStatus;
        _currentStatus = newStatus;
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order status updated to ${newStatus.toUpperCase()}'),
          backgroundColor: Colors.green,
        ),
      );

      if (newStatus == 'paid') {
        _showGenerateTrackingDialog();
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showGenerateTrackingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.local_shipping, color: Colors.blue.shade700),
            const SizedBox(width: 8),
            const Text('Generate Tracking Number'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter a tracking number for this order:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _trackingController,
              decoration: InputDecoration(
                hintText: 'e.g., TRK-2024-001',
                prefixIcon: const Icon(Icons.local_shipping),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _trackingController.clear();
              Navigator.pop(context);
            },
            child: const Text('Skip'),
          ),
          ElevatedButton(
            onPressed: _isGeneratingTracking ? null : () => _generateTrackingNumber(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
            ),
            child: _isGeneratingTracking
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Generate & Ship'),
          ),
        ],
      ),
    );
  }

  Future<void> _generateTrackingNumber() async {
    if (_trackingController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a tracking number'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isGeneratingTracking = true);

    try {
      final updateData = {
        'tracking_number': _trackingController.text.trim(),
        'status': 'shipped',
        'updated_at': DateTime.now().toIso8601String(),
        if (_destinationLocation != null) ...{
          'customer_lat': _destinationLocation!.latitude,
          'customer_lng': _destinationLocation!.longitude,
        }
      };
      
      await Supabase.instance.client
          .from('orders')
          .update(updateData)
          .eq('id', _order['id']);

      setState(() {
        _order['tracking_number'] = _trackingController.text.trim();
        _order['status'] = 'shipped';
        _currentStatus = 'shipped';
        _isGeneratingTracking = false;
      });

      Navigator.pop(context);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tracking number generated and order shipped!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() => _isGeneratingTracking = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
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

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending': return Icons.pending;
      case 'processing': return Icons.settings;
      case 'paid': return Icons.payment;
      case 'shipped': return Icons.local_shipping;
      case 'delivered': return Icons.check_circle;
      case 'cancelled': return Icons.cancel;
      default: return Icons.circle;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          'Order #${_order['order_number'] ?? 'N/A'}',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: isDark ? Colors.grey.shade800 : Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              Icons.refresh,
              color: isDark ? Colors.white : Colors.grey.shade700,
            ),
            onPressed: _initializeTrackingData,
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildOrderSummaryCard(isDark),
              const SizedBox(height: 16),
              _buildStatusTimeline(isDark),
              const SizedBox(height: 16),
              _buildLocationUpdateSection(isDark),
              const SizedBox(height: 16),
              _buildLiveMap(isDark),
              const SizedBox(height: 16),
              _buildRouteStatus(isDark),
              const SizedBox(height: 16),
              _buildStatusUpdateSection(isDark),
              const SizedBox(height: 16),
              _buildOrderDetails(isDark),
              const SizedBox(height: 16),
              _buildCustomerInfo(isDark),
              const SizedBox(height: 16),
              if (_order['tracking_number'] != null)
                _buildTrackingInfo(isDark),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderSummaryCard(bool isDark) {
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
                'Order Summary',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.grey.shade900,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getStatusColor(_order['status']).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getStatusIcon(_order['status']),
                      size: 16,
                      color: _getStatusColor(_order['status']),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _getStatusLabel(_order['status']),
                      style: TextStyle(
                        color: _getStatusColor(_order['status']),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order Date',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _order['created_at'] != null
                          ? (_order['created_at'] as String).substring(0, 10)
                          : 'N/A',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white : Colors.grey.shade900,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
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
                      '${_order['total_amount']} XAF',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusTimeline(bool isDark) {
    final currentIndex = _statusOptions.indexOf(_order['status']);
    
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
            'Order Status Timeline',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.grey.shade900,
            ),
          ),
          const SizedBox(height: 16),
          ...List.generate(_statusOptions.length, (index) {
            final status = _statusOptions[index];
            final isCompleted = index <= currentIndex;
            final isCurrent = index == currentIndex;
            final hasLine = index < _statusOptions.length - 1;
            
            return _buildTimelineItem(
              status: status,
              label: _getStatusLabel(status),
              icon: _getStatusIcon(status),
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
    required String status,
    required String label,
    required IconData icon,
    required bool isCompleted,
    required bool isCurrent,
    required bool hasLine,
    required bool isDark,
  }) {
    final color = isCompleted 
        ? _getStatusColor(status)
        : (isDark ? Colors.grey.shade600 : Colors.grey.shade400);
    
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
                  icon,
                  color: isCompleted ? color : (isDark ? Colors.grey.shade600 : Colors.grey.shade400),
                  size: 16,
                ),
              ),
              if (hasLine)
                Container(
                  width: 2,
                  height: 40,
                  color: isCompleted 
                      ? color
                      : (isDark ? Colors.grey.shade700 : Colors.grey.shade300),
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
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                    color: isCompleted 
                        ? (isDark ? Colors.white : Colors.grey.shade900)
                        : (isDark ? Colors.grey.shade500 : Colors.grey.shade500),
                  ),
                ),
                if (isCurrent)
                  Text(
                    'Current status',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (isCurrent)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'In Progress',
              style: TextStyle(
                fontSize: 10,
                color: Colors.blue.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLocationUpdateSection(bool isDark) {
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
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_on, color: Colors.blue.shade700),
              const SizedBox(width: 8),
              Text(
                'Update Package Location',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.grey.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Enter the current GPS coordinates of the package:',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _locationLatController,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Latitude',
                    hintText: 'e.g., 4.0511',
                    prefixIcon: const Icon(Icons.arrow_upward, size: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: isDark ? Colors.grey.shade700 : Colors.grey.shade50,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _locationLngController,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Longitude',
                    hintText: 'e.g., 9.7679',
                    prefixIcon: const Icon(Icons.arrow_forward, size: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: isDark ? Colors.grey.shade700 : Colors.grey.shade50,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _locationNameController,
            decoration: InputDecoration(
              labelText: 'Location Name (Optional)',
              hintText: 'e.g., Warehouse B, Transit Point, etc.',
              prefixIcon: const Icon(Icons.place, size: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: isDark ? Colors.grey.shade700 : Colors.grey.shade50,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isUpdatingLocation ? null : _updatePackageLocation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: _isUpdatingLocation
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.location_pin),
                  label: Text(
                    _isUpdatingLocation ? 'Updating...' : 'Update Location',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.circle, color: Colors.green, size: 10),
                    const SizedBox(width: 6),
                    Text(
                      'Live',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange.shade700, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'You can get GPS coordinates from Google Maps. '
                    'Right-click on a location and select "What\'s here?" '
                    'to see the coordinates.',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.orange.shade700,
                    ),
                  ),
                ),
              ],
            ),
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
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.yourcompany.app',
                    additionalOptions: const {
                      'attribution': '© OpenStreetMap contributors',
                    },
                  ),
                  
                  // Route Polyline - Shows route from company to destination
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
                      // START: Company/Warehouse Location
                      if (_currentLocation != null)
                        Marker(
                          point: _currentLocation!,
                          width: 50,
                          height: 50,
                          alignment: Alignment.center,
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.blue.shade700,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blue.withOpacity(0.5),
                                  blurRadius: 10,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.business,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                        ),
                      
                      // END: Customer/Package Location
                      if (_destinationLocation != null)
                        Marker(
                          point: _destinationLocation!,
                          width: 50,
                          height: 50,
                          alignment: Alignment.center,
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.red.shade600,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.red.withOpacity(0.5),
                                  blurRadius: 10,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.location_on,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                        ),
                    ],
                  ),
                  
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

  Widget _buildRouteStatus(bool isDark) {
    if (_routePoints.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey.shade800 : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange.shade700),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Route: $_routeStatus',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.grey.shade900,
                ),
              ),
            ),
          ],
        ),
      );
    }
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green.shade700),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Route: $_routeStatus',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.grey.shade900,
                  ),
                ),
                Text(
                  'From Company: ${_currentLocation?.latitude.toStringAsFixed(4)}, ${_currentLocation?.longitude.toStringAsFixed(4)}',
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
                Text(
                  'To Package: ${_destinationLocation?.latitude.toStringAsFixed(4)}, ${_destinationLocation?.longitude.toStringAsFixed(4)}',
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusUpdateSection(bool isDark) {
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
            'Update Status',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.grey.shade900,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _order['status'],
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  items: _statusOptions.map((status) {
                    return DropdownMenuItem(
                      value: status,
                      child: Row(
                        children: [
                          Icon(
                            _getStatusIcon(status),
                            color: _getStatusColor(status),
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(_getStatusLabel(status)),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (newStatus) {
                    if (newStatus != null && newStatus != _order['status']) {
                      _updateOrderStatus(newStatus);
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              if (_order['status'] == 'paid' && _order['tracking_number'] == null)
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _showGenerateTrackingDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.local_shipping),
                  label: const Text('Generate Tracking'),
                ),
            ],
          ),
          if (_order['status'] == 'paid' && _order['tracking_number'] == null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange.shade700, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This order is paid. Generate a tracking number to ship it.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOrderDetails(bool isDark) {
    final products = _order['products'] as List? ?? [];
    
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
            'Order Items (${products.length})',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.grey.shade900,
            ),
          ),
          const SizedBox(height: 12),
          ...products.map((item) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.shopping_bag, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['product_name'] ?? 'Product',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white : Colors.grey.shade900,
                          ),
                        ),
                        Text(
                          'Qty: ${item['quantity']} × ${item['price']} XAF',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${item['quantity'] * item['price']} XAF',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.grey.shade900,
                    ),
                  ),
                ],
              ),
            );
          }),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.grey.shade900,
                ),
              ),
              Text(
                '${_order['total_amount']} XAF',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerInfo(bool isDark) {
    final customerName = _order['customer_name'] ?? 
        _order['profiles']?['full_name'] ?? 
        'Customer';
    final customerEmail = _order['customer_email'] ?? 
        _order['profiles']?['email'] ?? 
        '';
    
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
            'Customer Information',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.grey.shade900,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: isDark ? Colors.grey.shade700 : Colors.blue.shade50,
                child: Text(
                  customerName.isNotEmpty ? customerName[0].toUpperCase() : 'C',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.grey.shade300 : Colors.blue.shade700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customerName,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.grey.shade900,
                      ),
                    ),
                    Text(
                      customerEmail,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_order['shipping_address'] != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.location_on, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _order['shipping_address'],
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ),
          ],
          // Customer Location (for admin reference)
          if (_order['customer_lat'] != null && _order['customer_lng'] != null)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.location_pin, size: 16, color: Colors.green.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Package Location: ${_order['customer_lat']}, ${_order['customer_lng']}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTrackingInfo(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_shipping, color: Colors.blue.shade700),
              const SizedBox(width: 8),
              Text(
                'Tracking Information',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.grey.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                        _order['tracking_number'] ?? 'N/A',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, color: Colors.blue),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Tracking number copied!'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green.shade700, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _order['status'] == 'shipped' 
                        ? 'Order has been shipped and is on its way to the customer.'
                        : 'Tracking number generated. Ship the order to activate tracking.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}