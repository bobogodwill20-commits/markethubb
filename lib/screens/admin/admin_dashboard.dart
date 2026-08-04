import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../../theme/theme_provider.dart';
import 'admin_orders.dart';
import 'admin_sellers.dart';
import 'admin_chat.dart';
import 'admin_analytics.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late List<Widget> _pages;
  bool _isSidebarCollapsed = false;
  
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _animationController.forward();
    
    _pages = const [
      AdminOverview(),
      AdminOrdersScreen(),
      AdminSellersScreen(),
      AdminChatScreen(),
      AdminAnalyticsScreen(),
    ];
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isMobile = MediaQuery.of(context).size.width < 900;
    final sidebarWidth = isMobile ? 0.0 : (_isSidebarCollapsed ? 80.0 : 280.0);
    
    return Scaffold(
      key: _scaffoldKey,
      body: Row(
        children: [
          // Sidebar Navigation
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: sidebarWidth,
            decoration: BoxDecoration(
              color: theme.cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                  blurRadius: 10,
                ),
              ],
            ),
            child: isMobile 
                ? const SizedBox.shrink()
                : _buildSidebar(isDark, isMobile),
          ),
          // Main Content
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _pages[_selectedIndex],
            ),
          ),
        ],
      ),
      // Floating Action Button positioned at top to avoid blocking content
      floatingActionButton: isMobile
          ? Container(
              margin: const EdgeInsets.only(top: 16),
              child: FloatingActionButton(
                onPressed: () {
                  _scaffoldKey.currentState?.openDrawer();
                },
                backgroundColor: Colors.blue.shade700,
                child: const Icon(Icons.menu, color: Colors.white),
                elevation: 6,
                mini: true,
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endTop,
      drawer: isMobile ? _buildMobileDrawer(isDark) : null,
    );
  }

  Widget _buildSidebar(bool isDark, bool isMobile) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Colors.blue, Colors.purple],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.3),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: const Icon(Icons.store, color: Colors.white),
              ),
              if (!_isSidebarCollapsed) ...[
                const SizedBox(width: 12),
                Text(
                  'Admin Panel',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.grey.shade800,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    _isSidebarCollapsed ? Icons.chevron_right : Icons.chevron_left,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() => _isSidebarCollapsed = !_isSidebarCollapsed);
                  },
                ),
              ],
            ],
          ),
        ),
        const Divider(),
        Expanded(
          child: Column(
            children: [
              _buildNavItem(Icons.dashboard_outlined, 'Overview', 0, isDark),
              _buildNavItem(Icons.shopping_bag_outlined, 'Orders', 1, isDark),
              _buildNavItem(Icons.people_outline, 'Sellers', 2, isDark),
              _buildNavItem(Icons.chat_outlined, 'Chat', 3, isDark),
              _buildNavItem(Icons.analytics_outlined, 'Analytics', 4, isDark),
            ],
          ),
        ),
        const Divider(),
        // Theme Toggle
        ListTile(
          leading: Icon(
            isDark ? Icons.light_mode : Icons.dark_mode,
            color: isDark ? Colors.amber : Colors.grey.shade700,
          ),
          title: _isSidebarCollapsed
              ? null
              : Text(
                  isDark ? 'Light Mode' : 'Dark Mode',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.grey.shade700,
                  ),
                ),
          onTap: () {
            final provider = Provider.of<ThemeProvider>(context, listen: false);
            provider.toggleTheme();
          },
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.logout, color: Colors.red),
          title: _isSidebarCollapsed
              ? null
              : const Text(
                  'Logout',
                  style: TextStyle(color: Colors.red),
                ),
          onTap: () async {
            await Supabase.instance.client.auth.signOut();
            if (mounted) {
              Navigator.pushReplacementNamed(context, '/login');
            }
          },
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildMobileDrawer(bool isDark) {
    return Drawer(
      child: Container(
        color: isDark ? Colors.grey.shade900 : Colors.white,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue, Colors.purple],
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.store, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Admin Panel',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  _buildNavItem(Icons.dashboard_outlined, 'Overview', 0, isDark),
                  _buildNavItem(Icons.shopping_bag_outlined, 'Orders', 1, isDark),
                  _buildNavItem(Icons.people_outline, 'Sellers', 2, isDark),
                  _buildNavItem(Icons.chat_outlined, 'Chat', 3, isDark),
                  _buildNavItem(Icons.analytics_outlined, 'Analytics', 4, isDark),
                ],
              ),
            ),
            const Divider(),
            ListTile(
              leading: Icon(
                isDark ? Icons.light_mode : Icons.dark_mode,
                color: isDark ? Colors.amber : Colors.grey.shade700,
              ),
              title: Text(
                isDark ? 'Light Mode' : 'Dark Mode',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.grey.shade700,
                ),
              ),
              onTap: () {
                final provider = Provider.of<ThemeProvider>(context, listen: false);
                provider.toggleTheme();
                Navigator.pop(context);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text(
                'Logout',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () async {
                await Supabase.instance.client.auth.signOut();
                if (mounted) {
                  Navigator.pushReplacementNamed(context, '/login');
                }
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
  
  Widget _buildNavItem(IconData icon, String title, int index, bool isDark) {
    final isSelected = _selectedIndex == index;
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected 
            ? (isDark ? Colors.blue.withOpacity(0.2) : Colors.blue.shade50) 
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : [],
      ),
      child: ListTile(
        leading: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: EdgeInsets.all(isSelected ? 8 : 4),
          decoration: BoxDecoration(
            color: isSelected 
                ? Colors.blue.shade700 
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon, 
            color: isSelected 
                ? Colors.white
                : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
            size: isSelected ? 22 : 24,
          ),
        ),
        title: AnimatedSize(
          duration: const Duration(milliseconds: 300),
          child: Text(
            title,
            style: TextStyle(
              color: isSelected 
                  ? Colors.blue.shade700 
                  : (isDark ? Colors.grey.shade300 : Colors.grey.shade700),
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
        trailing: isSelected 
            ? AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 4,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.blue.shade700,
                  borderRadius: BorderRadius.circular(2),
                ),
              )
            : null,
        onTap: () {
          setState(() => _selectedIndex = index);
          if (MediaQuery.of(context).size.width < 900) {
            Navigator.pop(context);
          }
        },
      ),
    );
  }
}

// ============================================
// AdminOverview Widget
// ============================================

class AdminOverview extends StatefulWidget {
  const AdminOverview({super.key});

  @override
  State<AdminOverview> createState() => _AdminOverviewState();
}

class _AdminOverviewState extends State<AdminOverview> with SingleTickerProviderStateMixin {
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _recentOrders = [];
  bool _isLoading = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
    _loadData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      final orders = await Supabase.instance.client
          .from('orders')
          .select('status, total_amount');
      
      final pending = orders.where((o) => o['status'] == 'pending').length;
      
      final sellers = await Supabase.instance.client
          .from('profiles')
          .select('id')
          .eq('role', 'seller');
      
      final delivered = orders.where((o) => o['status'] == 'delivered');
      final revenue = delivered.fold<double>(
        0, (sum, order) => sum + (order['total_amount'] as num).toDouble()
      );
      
      final recent = await Supabase.instance.client
          .from('orders')
          .select('*, profiles!customer_id(full_name)')
          .order('created_at', ascending: false)
          .limit(5);
      
      setState(() {
        _stats = {
          'totalOrders': orders.length,
          'pendingOrders': pending,
          'totalSellers': sellers.length,
          'revenue': revenue,
        };
        _recentOrders = List<Map<String, dynamic>>.from(recent);
        _isLoading = false;
      });
      
      _animationController.forward();
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  String _formatCurrency(double amount) {
    return '${amount.toStringAsFixed(0)} XAF';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isMobile = MediaQuery.of(context).size.width < 600;
    final crossAxisCount = isMobile ? 2 : 4;
    
    return Scaffold(
      backgroundColor: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
      body: _isLoading
          ? Center(
              child: SpinKitFadingGrid(
                color: Colors.blue.shade700,
                size: 50,
              ),
            )
          : FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Dashboard Overview',
                                style: TextStyle(
                                  fontSize: isMobile ? 24 : 28,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.grey.shade900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Welcome back, Admin',
                                style: TextStyle(
                                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                  fontSize: isMobile ? 14 : 16,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: isDark ? Colors.grey.shade800 : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                            child: IconButton(
                              onPressed: _loadData,
                              icon: AnimatedRotation(
                                duration: const Duration(milliseconds: 500),
                                turns: _isLoading ? 1.0 : 0.0,
                                child: Icon(
                                  Icons.refresh,
                                  color: isDark ? Colors.white : Colors.grey.shade700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      
                      // Stats Grid with Animation
                      GridView.count(
                        shrinkWrap: true,
                        crossAxisCount: crossAxisCount,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        children: [
                          _buildStatCard(
                            'Total Orders',
                            _stats['totalOrders']?.toString() ?? '0',
                            Icons.shopping_bag,
                            Colors.blue,
                            isDark,
                            0,
                          ),
                          _buildStatCard(
                            'Pending Orders',
                            _stats['pendingOrders']?.toString() ?? '0',
                            Icons.pending,
                            Colors.orange,
                            isDark,
                            1,
                          ),
                          _buildStatCard(
                            'Total Sellers',
                            _stats['totalSellers']?.toString() ?? '0',
                            Icons.people,
                            Colors.green,
                            isDark,
                            2,
                          ),
                          _buildStatCard(
                            'Revenue',
                            _formatCurrency(_stats['revenue'] ?? 0),
                            Icons.attach_money,
                            Colors.purple,
                            isDark,
                            3,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      
                      // Recent Orders
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 500),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: theme.cardColor,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
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
                                  '📋 Recent Orders',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : Colors.grey.shade900,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {},
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.blue.shade700,
                                  ),
                                  child: const Text(
                                    'View All →',
                                    style: TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            if (_recentOrders.isEmpty)
                              Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(40),
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.inbox_outlined,
                                        size: 60,
                                        color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'No recent orders',
                                        style: TextStyle(
                                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            else
                              ..._recentOrders.asMap().entries.map((entry) {
                                final index = entry.key;
                                final order = entry.value;
                                return TweenAnimationBuilder(
                                  tween: Tween<double>(begin: 0, end: 1),
                                  duration: Duration(milliseconds: 400 + (index * 100)),
                                  curve: Curves.easeOut,
                                  builder: (context, value, child) {
                                    final clampedValue = value.clamp(0.0, 1.0);
                                    return Opacity(
                                      opacity: clampedValue,
                                      child: Transform.translate(
                                        offset: Offset(20 * (1 - clampedValue), 0),
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: _buildRecentOrderItem(order, isDark),
                                );
                              }),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, bool isDark, int index) {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 500 + (index * 100)),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) {
        final clampedScale = scale.clamp(0.0, 1.0);
        return Transform.scale(
          scale: 0.8 + (0.2 * clampedScale),
          child: Opacity(
            opacity: clampedScale,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade800 : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [color, color.withOpacity(0.5)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: Colors.white, size: 24),
                  ),
                  const SizedBox(height: 12),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 300),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.grey.shade900,
                    ),
                    child: Text(value),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: TextStyle(
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecentOrderItem(Map<String, dynamic> order, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _getStatusColor(order['status']).withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _getStatusIcon(order['status']),
              color: _getStatusColor(order['status']),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Order #${order['order_number']}',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.grey.shade900,
                  ),
                ),
                Text(
                  order['profiles']?['full_name'] ?? 'Customer',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _getStatusColor(order['status']).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              order['status'].toString().toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: _getStatusColor(order['status']),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${(order['total_amount'] as num).toStringAsFixed(0)} XAF',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.grey.shade900,
            ),
          ),
        ],
      ),
    );
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
}