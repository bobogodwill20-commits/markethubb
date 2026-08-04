import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

class AdminSellersScreen extends StatefulWidget {
  const AdminSellersScreen({super.key});

  @override
  State<AdminSellersScreen> createState() => _AdminSellersScreenState();
}

class _AdminSellersScreenState extends State<AdminSellersScreen> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _sellers = [];
  List<Map<String, dynamic>> _customers = [];
  bool _isLoading = true;
  int _selectedTab = 0; // 0 = Sellers, 1 = Customers
  String _searchQuery = '';
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _animationController.forward();
    _fetchData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    
    try {
      // Fetch sellers
      final sellersResponse = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('role', 'seller')
          .order('created_at', ascending: false);
      
      // Fetch customers
      final customersResponse = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('role', 'customer')
          .order('created_at', ascending: false);
      
      setState(() {
        _sellers = List<Map<String, dynamic>>.from(sellersResponse);
        _customers = List<Map<String, dynamic>>.from(customersResponse);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredSellers {
    if (_searchQuery.isEmpty) return _sellers;
    return _sellers.where((seller) {
      final name = (seller['full_name'] ?? '').toLowerCase();
      final email = (seller['email'] ?? '').toLowerCase();
      final search = _searchQuery.toLowerCase();
      return name.contains(search) || email.contains(search);
    }).toList();
  }

  List<Map<String, dynamic>> get _filteredCustomers {
    if (_searchQuery.isEmpty) return _customers;
    return _customers.where((customer) {
      final name = (customer['full_name'] ?? '').toLowerCase();
      final email = (customer['email'] ?? '').toLowerCase();
      final search = _searchQuery.toLowerCase();
      return name.contains(search) || email.contains(search);
    }).toList();
  }

  Future<void> _validateSeller(String sellerId, String email) async {
    final token = DateTime.now().millisecondsSinceEpoch.toString();
    
    await Supabase.instance.client
        .from('profiles')
        .update({
          'is_verified': true,
          'verification_token': token,
        })
        .eq('id', sellerId);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.verified, color: Colors.green.shade700),
            const SizedBox(width: 8),
            const Text('Verification Token'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Send this token to the seller:'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade50, Colors.purple.shade50],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: SelectableText(
                token,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  color: Colors.blue,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.email, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      email,
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              // Copy token to clipboard
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Token copied to clipboard!')),
              );
            },
            icon: const Icon(Icons.copy),
            label: const Text('Copy Token'),
          ),
        ],
      ),
    );
    
    _fetchData();
  }

  Future<void> _toggleUserStatus(String userId, bool currentStatus, String role) async {
    final action = currentStatus ? 'deactivate' : 'activate';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              currentStatus ? Icons.warning_amber_rounded : Icons.check_circle,
              color: currentStatus ? Colors.orange : Colors.green,
            ),
            const SizedBox(width: 8),
            Text(currentStatus ? 'Deactivate Account' : 'Activate Account'),
          ],
        ),
        content: Text(
          currentStatus 
              ? 'Are you sure you want to deactivate this ${role.toLowerCase()}\'s account? They will not be able to access the app.'
              : 'Are you sure you want to activate this ${role.toLowerCase()}\'s account? They will regain full access.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: currentStatus ? Colors.red : Colors.green,
            ),
            child: Text(currentStatus ? 'Deactivate' : 'Activate'),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      await Supabase.instance.client
          .from('profiles')
          .update({
            'is_active': !currentStatus,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userId);
      
      _fetchData();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Account ${currentStatus ? 'deactivated' : 'activated'} successfully'),
          backgroundColor: currentStatus ? Colors.orange : Colors.green,
        ),
      );
    }
  }

  Future<void> _revokeVerification(String sellerId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Revoke Verification'),
          ],
        ),
        content: const Text(
          'Are you sure you want to revoke this seller\'s verification? '
          'They will lose access to seller features until re-verified.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Revoke'),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      await Supabase.instance.client
          .from('profiles')
          .update({
            'is_verified': false,
            'verification_token': null,
          })
          .eq('id', sellerId);
      
      _fetchData();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Seller verification revoked'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isMobile = MediaQuery.of(context).size.width < 600;
    
    return Scaffold(
      backgroundColor: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('User Management'),
        backgroundColor: isDark ? Colors.grey.shade800 : Colors.white,
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: AnimatedRotation(
                duration: const Duration(milliseconds: 500),
                turns: _isLoading ? 1.0 : 0.0,
                child: Icon(
                  Icons.refresh,
                  color: isDark ? Colors.white : Colors.grey.shade700,
                ),
              ),
              onPressed: _fetchData,
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                // Search Bar
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() => _searchQuery = value);
                    },
                    decoration: InputDecoration(
                      hintText: 'Search users...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Tab Toggle
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    children: [
                      _buildTabButton('Sellers', 0, isDark),
                      _buildTabButton('Customers', 1, isDark),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
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
              child: _selectedTab == 0
                  ? _buildUserList(_filteredSellers, 'sellers', isDark, isMobile)
                  : _buildUserList(_filteredCustomers, 'customers', isDark, isMobile),
            ),
    );
  }

  Widget _buildTabButton(String title, int index, bool isDark) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedTab = index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected 
              ? (isDark ? Colors.blue.shade700 : Colors.blue.shade700)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : (isDark ? Colors.grey.shade300 : Colors.grey.shade700),
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildUserList(List<Map<String, dynamic>> users, String type, bool isDark, bool isMobile) {
    if (users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              type == 'sellers' ? Icons.people_outline : Icons.person_outline,
              size: 80,
              color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No ${type == 'sellers' ? 'sellers' : 'customers'} found',
              style: TextStyle(
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              type == 'sellers' 
                  ? 'Sellers will appear here once they register'
                  : 'Customers will appear here once they register',
              style: TextStyle(
                color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        final isVerified = user['is_verified'] ?? false;
        final isActive = user['is_active'] ?? true;
        final isSeller = type == 'sellers';
        
        return TweenAnimationBuilder(
          tween: Tween<double>(begin: 0, end: 1),
          duration: Duration(milliseconds: 300 + (index * 50)),
          curve: Curves.easeOut,
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(20 * (1 - value), 0),
                child: child,
              ),
            );
          },
          child: _buildUserCard(user, isSeller, isVerified, isActive, isDark, isMobile),
        );
      },
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user, bool isSeller, bool isVerified, bool isActive, bool isDark, bool isMobile) {
    final fullName = user['full_name']?.toString() ?? 'No name';
    final email = user['email']?.toString() ?? '';
    final avatarUrl = user['avatar_url']?.toString();
    final createdAt = user['created_at']?.toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Avatar
                CircleAvatar(
                  radius: isMobile ? 30 : 35,
                  backgroundColor: isDark ? Colors.grey.shade700 : Colors.blue.shade50,
                  backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                      ? NetworkImage(avatarUrl)
                      : null,
                  child: (avatarUrl == null || avatarUrl.isEmpty) && fullName.isNotEmpty
                      ? Text(
                          fullName[0].toUpperCase(),
                          style: TextStyle(
                            fontSize: isMobile ? 20 : 24,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.grey.shade300 : Colors.blue.shade700,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 16),
                // User Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              fullName,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: isMobile ? 16 : 18,
                                color: isDark ? Colors.white : Colors.grey.shade900,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isSeller && isVerified)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.verified, size: 12, color: Colors.green.shade700),
                                  const SizedBox(width: 2),
                                  Text(
                                    'Verified',
                                    style: TextStyle(
                                      fontSize: 8,
                                      color: Colors.green.shade700,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.email, size: 14, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              email,
                              style: TextStyle(
                                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (createdAt != null) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(Icons.calendar_today, size: 12, color: isDark ? Colors.grey.shade500 : Colors.grey.shade500),
                            const SizedBox(width: 4),
                            Text(
                              'Joined: ${createdAt.substring(0, 10)}',
                              style: TextStyle(
                                color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                // Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isActive
                        ? (isVerified ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1))
                        : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isActive
                            ? (isVerified ? Icons.check_circle : Icons.pending)
                            : Icons.block,
                        size: 14,
                        color: isActive
                            ? (isVerified ? Colors.green : Colors.orange)
                            : Colors.red,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isActive
                            ? (isVerified ? 'Active' : 'Pending')
                            : 'Inactive',
                        style: TextStyle(
                          color: isActive
                              ? (isVerified ? Colors.green : Colors.orange)
                              : Colors.red,
                          fontWeight: FontWeight.w600,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Action Buttons
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (isSeller && !isVerified)
                  ElevatedButton.icon(
                    onPressed: () => _validateSeller(user['id'], email),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.check_circle, size: 18),
                    label: const Text(
                      'Verify',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                if (isSeller && isVerified)
                  OutlinedButton.icon(
                    onPressed: () => _revokeVerification(user['id']),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      side: const BorderSide(color: Colors.orange),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.block, size: 18),
                    label: const Text(
                      'Revoke',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ElevatedButton.icon(
                  onPressed: () => _toggleUserStatus(user['id'], isActive, isSeller ? 'Seller' : 'Customer'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isActive ? Colors.orange : Colors.green,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: Icon(
                    isActive ? Icons.block : Icons.check_circle,
                    size: 18,
                  ),
                  label: Text(
                    isActive ? 'Deactivate' : 'Activate',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}