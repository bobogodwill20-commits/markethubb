import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../../theme/theme_provider.dart';
import 'seller_products.dart';
import 'seller_orders.dart';
import 'seller_chat.dart';
import 'seller_profile.dart';
import 'seller_inventory.dart';
import 'seller_dashboard_home.dart';

class SellerDashboard extends StatefulWidget {
  const SellerDashboard({super.key});

  @override
  State<SellerDashboard> createState() => _SellerDashboardState();
}

class _SellerDashboardState extends State<SellerDashboard> with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  late List<Widget> _pages;
  Map<String, dynamic>? _sellerData;
  bool _isLoading = true;
  bool _isSidebarCollapsed = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

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
    _loadSellerData();
    _initializePages();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _initializePages() {
    _pages = [
      const SellerDashboardHome(),
      const SellerProductsScreen(),
      const SellerOrdersScreen(),
      const SellerInventoryScreen(),
      const SellerChatScreen(),
      const SellerProfileScreen(),
    ];
  }

  Future<void> _loadSellerData() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      try {
        final response = await Supabase.instance.client
            .from('profiles')
            .select()
            .eq('id', user.id)
            .single();
        if (mounted) {
          setState(() {
            _sellerData = response;
            _isLoading = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isMobile = MediaQuery.of(context).size.width < 900;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
      body: _isLoading
          ? const Center(
              child: SpinKitFadingGrid(
                color: Colors.blue,
                size: 50,
              ),
            )
          : SafeArea(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Desktop Sidebar
                  if (!isMobile)
                    _buildDesktopSidebar(isDark),
                  // Main Content
                  Expanded(
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: _pages[_selectedIndex],
                    ),
                  ),
                ],
              ),
            ),
      // Floating Action Button positioned at top to avoid blocking chat input
      floatingActionButton: isMobile
          ? Container(
              margin: const EdgeInsets.only(top: 16),
              child: FloatingActionButton(
                onPressed: () {
                  if (_scaffoldKey.currentState != null) {
                    _scaffoldKey.currentState!.openDrawer();
                  }
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

  Widget _buildDesktopSidebar(bool isDark) {
    final fullName = _sellerData?['full_name'] ?? 'Seller Name';
    final avatarUrl = _sellerData?['avatar_url'];
    final isCollapsed = _isSidebarCollapsed;
    final width = isCollapsed ? 80.0 : 280.0;

    return Container(
      width: width,
      height: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800 : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        children: [
          // Profile Section
          Container(
            padding: EdgeInsets.symmetric(vertical: isCollapsed ? 16 : 24, horizontal: 16),
            child: Column(
              children: [
                CircleAvatar(
                  radius: isCollapsed ? 25 : 40,
                  backgroundColor: isDark ? Colors.grey.shade700 : Colors.blue.shade100,
                  backgroundImage: avatarUrl != null && avatarUrl.toString().isNotEmpty
                      ? NetworkImage(avatarUrl)
                      : null,
                  child: avatarUrl == null || avatarUrl.toString().isEmpty
                      ? Text(
                          fullName.isNotEmpty ? fullName[0].toUpperCase() : 'S',
                          style: TextStyle(
                            fontSize: isCollapsed ? 18 : 28,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.grey.shade300 : Colors.blue.shade700,
                          ),
                        )
                      : null,
                ),
                if (!isCollapsed) ...[
                  const SizedBox(height: 8),
                  Text(
                    fullName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.grey.shade900,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Seller',
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(),
          // Navigation Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 4),
              children: [
                _buildNavItem(Icons.dashboard_outlined, 'Dashboard', 0, isDark),
                _buildNavItem(Icons.inventory_2_outlined, 'Products', 1, isDark),
                _buildNavItem(Icons.shopping_bag_outlined, 'Orders', 2, isDark),
                _buildNavItem(Icons.warehouse, 'Inventory', 3, isDark),
                _buildNavItem(Icons.chat_outlined, 'Messages', 4, isDark),
                _buildNavItem(Icons.person_outline, 'Profile', 5, isDark),
              ],
            ),
          ),
          const Divider(),
          // Bottom Actions
          Column(
            children: [
              ListTile(
                leading: Icon(
                  isDark ? Icons.light_mode : Icons.dark_mode,
                  color: isDark ? Colors.amber : Colors.grey.shade700,
                  size: 20,
                ),
                title: isCollapsed
                    ? null
                    : Text(
                        isDark ? 'Light Mode' : 'Dark Mode',
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.grey.shade700,
                          fontSize: 13,
                        ),
                      ),
                onTap: () {
                  final provider = Provider.of<ThemeProvider>(context, listen: false);
                  provider.toggleTheme();
                },
              ),
              ListTile(
                leading: Icon(
                  isCollapsed ? Icons.chevron_right : Icons.chevron_left,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  size: 20,
                ),
                title: isCollapsed
                    ? null
                    : Text(
                        'Collapse',
                        style: TextStyle(
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                onTap: () {
                  setState(() {
                    _isSidebarCollapsed = !_isSidebarCollapsed;
                  });
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red, size: 20),
                title: isCollapsed
                    ? null
                    : const Text(
                        'Logout',
                        style: TextStyle(color: Colors.red, fontSize: 13),
                      ),
                onTap: () async {
                  await Supabase.instance.client.auth.signOut();
                  if (mounted) {
                    Navigator.pushReplacementNamed(context, '/login');
                  }
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMobileDrawer(bool isDark) {
    final fullName = _sellerData?['full_name'] ?? 'Seller Name';
    final avatarUrl = _sellerData?['avatar_url'];
    
    return Drawer(
      child: Container(
        color: isDark ? Colors.grey.shade900 : Colors.white,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [Colors.blue.shade900, Colors.purple.shade900]
                      : [Colors.blue.shade600, Colors.purple.shade700],
                ),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.white.withOpacity(0.2),
                    backgroundImage: avatarUrl != null && avatarUrl.toString().isNotEmpty
                        ? NetworkImage(avatarUrl)
                        : null,
                    child: avatarUrl == null || avatarUrl.toString().isEmpty
                        ? Text(
                            fullName.isNotEmpty ? fullName[0].toUpperCase() : 'S',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    fullName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Seller',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 4),
                children: [
                  _buildNavItem(Icons.dashboard_outlined, 'Dashboard', 0, isDark),
                  _buildNavItem(Icons.inventory_2_outlined, 'Products', 1, isDark),
                  _buildNavItem(Icons.shopping_bag_outlined, 'Orders', 2, isDark),
                  _buildNavItem(Icons.warehouse, 'Inventory', 3, isDark),
                  _buildNavItem(Icons.chat_outlined, 'Messages', 4, isDark),
                  _buildNavItem(Icons.person_outline, 'Profile', 5, isDark),
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
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String title, int index, bool isDark) {
    final isSelected = _selectedIndex == index;
    final isCollapsed = _isSidebarCollapsed;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected 
            ? (isDark ? Colors.blue.withOpacity(0.2) : Colors.blue.shade50) 
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        leading: Icon(
          icon, 
          color: isSelected 
              ? Colors.blue.shade700 
              : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
          size: isSelected ? 22 : 20,
        ),
        title: isCollapsed
            ? null
            : Text(
                title,
                style: TextStyle(
                  color: isSelected 
                      ? Colors.blue.shade700 
                      : (isDark ? Colors.grey.shade300 : Colors.grey.shade700),
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 14,
                ),
              ),
        trailing: isSelected && !isCollapsed
            ? Container(
                width: 3,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.blue.shade700,
                  borderRadius: BorderRadius.circular(2),
                ),
              )
            : null,
        onTap: () {
          setState(() {
            _selectedIndex = index;
          });
          // Close the drawer when an item is tapped on mobile
          if (MediaQuery.of(context).size.width < 900) {
            Navigator.pop(context);
          }
        },
      ),
    );
  }
}