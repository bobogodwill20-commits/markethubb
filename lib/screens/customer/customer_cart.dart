import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../../services/payment_service.dart';

class CustomerCartScreen extends StatefulWidget {
  const CustomerCartScreen({super.key});

  @override
  State<CustomerCartScreen> createState() => _CustomerCartScreenState();
}

class _CustomerCartScreenState extends State<CustomerCartScreen> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _cartItems = [];
  bool _isLoading = true;
  bool _isCheckingOut = false;
  String _selectedPaymentMethod = 'MTN';
  String _selectedCheckoutOption = 'mobile_money';
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  final List<String> _paymentMethods = ['MTN', 'ORANGE'];
  final List<Map<String, dynamic>> _checkoutOptions = [
    {'value': 'mobile_money', 'label': 'Mobile Money', 'icon': Icons.phone_android, 'color': '#4CAF50'},
    {'value': 'delivery', 'label': 'Pay on Delivery', 'icon': Icons.delivery_dining, 'color': '#FF9800'},
  ];

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
    _animationController.forward();
    _fetchCart();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _fetchCart() async {
    setState(() => _isLoading = true);
    
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final response = await Supabase.instance.client
          .from('cart')
          .select('*, products(*)')
          .eq('customer_id', user.id);
      
      setState(() {
        _cartItems = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    }
  }

  Future<void> _updateQuantity(String cartId, int newQuantity) async {
    if (newQuantity <= 0) {
      await _removeItem(cartId);
      return;
    }
    
    await Supabase.instance.client
        .from('cart')
        .update({'quantity': newQuantity})
        .eq('id', cartId);
    
    _fetchCart();
  }

  Future<void> _removeItem(String cartId) async {
    await Supabase.instance.client
        .from('cart')
        .delete()
        .eq('id', cartId);
    
    _fetchCart();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Item removed from cart')),
    );
  }

  double get _totalPrice {
    double total = 0;
    for (var item in _cartItems) {
      final price = item['products']['price'] ?? 0;
      final quantity = item['quantity'] ?? 1;
      total += price * quantity;
    }
    return total;
  }

  String get _formattedTotal => '${_totalPrice.toStringAsFixed(0)} XAF';

  Future<void> _checkout() async {
    final result = await _showCheckoutDialog();
    if (result == null || result == false) return;
    
    setState(() => _isCheckingOut = true);
    
    final user = Supabase.instance.client.auth.currentUser;
    final userProfile = await Supabase.instance.client
        .from('profiles')
        .select()
        .eq('id', user!.id)
        .single();
    
    try {
      final orderNumber = 'ORD${DateTime.now().millisecondsSinceEpoch}';
      
      List<Map<String, dynamic>> orderItems = [];
      for (var item in _cartItems) {
        orderItems.add({
          'product_id': item['product_id'],
          'product_name': item['products']['name'],
          'quantity': item['quantity'],
          'price': item['price'],
        });
      }
      
      final sellerId = _cartItems.first['products']['seller_id'];
      
      String orderStatus = 'pending';
      String paymentStatus = 'pending';
      
      if (_selectedCheckoutOption == 'mobile_money') {
        final paymentResponse = await PaymentService.initializePayment(
          amount: _totalPrice,
          phone: _phoneController.text.trim(),
          provider: _selectedPaymentMethod,
          orderId: 'pending',
          orderNumber: orderNumber,
          email: userProfile['email'] ?? '',
          userId: user.id,
          redirectUrl: 'https://your-app.com/payment-callback',
        );
        
        if (paymentResponse['status'] == 'success') {
          orderStatus = 'paid';
          paymentStatus = 'completed';
        } else {
          throw Exception(paymentResponse['message']);
        }
      } else {
        orderStatus = 'pending';
        paymentStatus = 'pending_delivery';
      }
      
      await Supabase.instance.client.from('orders').insert({
        'order_number': orderNumber,
        'customer_id': user.id,
        'customer_name': userProfile['full_name'] ?? 'Customer',
        'customer_email': userProfile['email'] ?? '',
        'seller_id': sellerId,
        'products': orderItems,
        'total_amount': _totalPrice,
        'status': orderStatus,
        'payment_status': paymentStatus,
        'payment_method': _selectedCheckoutOption == 'mobile_money' ? _selectedPaymentMethod : 'Cash on Delivery',
        'shipping_address': _addressController.text.trim() ?? 'Customer Address',
        'phone_number': _phoneController.text.trim() ?? '',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
      
      for (var item in _cartItems) {
        await Supabase.instance.client
            .from('cart')
            .delete()
            .eq('id', item['id']);
        
        final newStock = (item['products']['stock'] ?? 0) - (item['quantity'] ?? 1);
        await Supabase.instance.client
            .from('products')
            .update({'stock': newStock})
            .eq('id', item['product_id']);
      }
      
      setState(() => _isCheckingOut = false);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_selectedCheckoutOption == 'mobile_money' 
              ? 'Payment successful! Order placed.' 
              : 'Order placed! Awaiting admin confirmation.'),
          backgroundColor: Colors.green,
        ),
      );
      
      _fetchCart();
      _showOrderConfirmation();
      
    } catch (e) {
      setState(() => _isCheckingOut = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showOrderConfirmation() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _selectedCheckoutOption == 'mobile_money' 
                    ? Colors.green.withOpacity(0.1) 
                    : Colors.orange.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _selectedCheckoutOption == 'mobile_money' 
                    ? Icons.check_circle 
                    : Icons.pending,
                color: _selectedCheckoutOption == 'mobile_money' 
                    ? Colors.green 
                    : Colors.orange,
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              _selectedCheckoutOption == 'mobile_money' 
                  ? 'Order Confirmed!' 
                  : 'Order Placed!',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _selectedCheckoutOption == 'mobile_money'
                  ? 'Your order has been placed and payment is confirmed.'
                  : 'Your order has been placed. Please wait for admin confirmation.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade50, Colors.purple.shade50],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildSummaryRow('Total Amount', _formattedTotal),
                  const SizedBox(height: 8),
                  _buildSummaryRow('Payment Method', 
                      _selectedCheckoutOption == 'mobile_money' 
                          ? _selectedPaymentMethod 
                          : 'Cash on Delivery'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Continue Shopping'),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey)),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
      ],
    );
  }

  Future<bool?> _showCheckoutDialog() {
    _phoneController.clear();
    _addressController.clear();
    String selectedProvider = _selectedPaymentMethod;
    String selectedOption = _selectedCheckoutOption;
    bool showPhoneField = selectedOption == 'mobile_money';
    
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text(
            'Checkout',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Choose Payment Method',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                ..._checkoutOptions.map((option) {
                  final isSelected = selectedOption == option['value'];
                  final color = Color(int.parse(option['color'].replaceAll('#', '0xFF')));
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedOption = option['value'];
                        showPhoneField = selectedOption == 'mobile_money';
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isSelected ? color.withOpacity(0.05) : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected ? color : Colors.grey.shade300,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isSelected ? color.withOpacity(0.1) : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              option['icon'],
                              color: isSelected ? color : Colors.grey,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              option['label'],
                              style: TextStyle(
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                color: isSelected ? color : Colors.grey.shade800,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          if (isSelected)
                            Icon(Icons.check_circle, color: color, size: 22),
                        ],
                      ),
                    ),
                  );
                }),
                
                const Divider(height: 24),
                
                if (showPhoneField) ...[
                  TextField(
                    controller: _phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number',
                      hintText: 'e.g., 670000000',
                      prefixText: '+237 ',
                      border: OutlineInputBorder(),
                      prefixStyle: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    keyboardType: TextInputType.phone,
                    maxLength: 9,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text(
                        'Provider:',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: selectedProvider,
                              isExpanded: true,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              items: _paymentMethods.map((method) {
                                return DropdownMenuItem(
                                  value: method,
                                  child: Row(
                                    children: [
                                      Icon(
                                        method == 'MTN' 
                                            ? Icons.phone_android 
                                            : Icons.phone_iphone,
                                        size: 18,
                                        color: Colors.blue.shade700,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(method),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                if (value != null) selectedProvider = value;
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                
                TextField(
                  controller: _addressController,
                  decoration: const InputDecoration(
                    labelText: 'Delivery Address',
                    hintText: 'Enter your delivery address',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.location_on),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade50, Colors.purple.shade50],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      _buildSummaryRow('Total', _formattedTotal),
                      const SizedBox(height: 8),
                      _buildSummaryRow('Payment', 
                          selectedOption == 'mobile_money' ? selectedProvider : 'Cash on Delivery'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (selectedOption == 'mobile_money') {
                  if (_phoneController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter your phone number'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                    return;
                  }
                  if (_phoneController.text.trim().length < 9) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter a valid phone number (9 digits)'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                    return;
                  }
                }
                
                if (_addressController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter your delivery address'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }
                
                setState(() {
                  _selectedCheckoutOption = selectedOption;
                  _selectedPaymentMethod = selectedProvider;
                });
                
                Navigator.pop(context, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Place Order'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          'My Cart',
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
            onPressed: _fetchCart,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: SpinKitFadingGrid(color: Colors.blue.shade700, size: 50))
          : _cartItems.isEmpty
              ? _buildEmptyState(isDark)
              : FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    children: [
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _cartItems.length,
                          itemBuilder: (context, index) {
                            final item = _cartItems[index];
                            final product = item['products'];
                            return _buildCartItem(item, product, isDark, index);
                          },
                        ),
                      ),
                      _buildCheckoutSection(isDark),
                    ],
                  ),
                ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.shopping_cart_outlined,
              size: 80,
              color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Your cart is empty',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.grey.shade900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start shopping to add items',
            style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Continue Shopping'),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItem(Map<String, dynamic> item, Map<String, dynamic> product, bool isDark, int index) {
    final imageUrl = product['images'] != null && product['images'].isNotEmpty
        ? product['images'][0]
        : '';
    
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 300 + (index * 50)),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(20 * (1 - value), 0),
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade800 : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(20),
                      ),
                      color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
                    ),
                    child: imageUrl.isNotEmpty && !imageUrl.startsWith('placeholder_')
                        ? ClipRRect(
                            borderRadius: const BorderRadius.horizontal(
                              left: Radius.circular(20),
                            ),
                            child: CachedNetworkImage(
                              imageUrl: imageUrl,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => const Center(
                                child: SpinKitFadingCircle(color: Colors.blue, size: 24),
                              ),
                              errorWidget: (context, url, error) => const Icon(
                                Icons.image,
                                color: Colors.grey,
                              ),
                            ),
                          )
                        : const Icon(Icons.image, color: Colors.grey),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product['name'] ?? 'Product',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: isDark ? Colors.white : Colors.grey.shade900,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${product['price']} XAF',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade700,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    IconButton(
                                      icon: Icon(Icons.remove, size: 18, color: isDark ? Colors.white : Colors.grey.shade700),
                                      onPressed: () => _updateQuantity(item['id'], (item['quantity'] ?? 1) - 1),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                    SizedBox(
                                      width: 30,
                                      child: Text(
                                        '${item['quantity']}',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? Colors.white : Colors.grey.shade900,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.add, size: 18, color: isDark ? Colors.white : Colors.grey.shade700),
                                      onPressed: () {
                                        if ((item['quantity'] ?? 1) < (product['stock'] ?? 0)) {
                                          _updateQuantity(item['id'], (item['quantity'] ?? 1) + 1);
                                        }
                                      },
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                onPressed: () => _removeItem(item['id']),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCheckoutSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800 : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total:',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.grey.shade900,
                ),
              ),
              Text(
                _formattedTotal,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedCheckoutOption = 'mobile_money'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _selectedCheckoutOption == 'mobile_money'
                          ? Colors.blue.shade700
                          : isDark ? Colors.grey.shade700 : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.phone_android,
                          color: _selectedCheckoutOption == 'mobile_money'
                              ? Colors.white
                              : isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          size: 20,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Mobile Money',
                          style: TextStyle(
                            color: _selectedCheckoutOption == 'mobile_money'
                                ? Colors.white
                                : isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                            fontWeight: _selectedCheckoutOption == 'mobile_money'
                                ? FontWeight.w600
                                : FontWeight.normal,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedCheckoutOption = 'delivery'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _selectedCheckoutOption == 'delivery'
                          ? Colors.blue.shade700
                          : isDark ? Colors.grey.shade700 : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.delivery_dining,
                          color: _selectedCheckoutOption == 'delivery'
                              ? Colors.white
                              : isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          size: 20,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Pay on Delivery',
                          style: TextStyle(
                            color: _selectedCheckoutOption == 'delivery'
                                ? Colors.white
                                : isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                            fontWeight: _selectedCheckoutOption == 'delivery'
                                ? FontWeight.w600
                                : FontWeight.normal,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isCheckingOut ? null : _checkout,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.blue.shade700,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isCheckingOut
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(
                      _selectedCheckoutOption == 'mobile_money'
                          ? 'Pay with Mobile Money'
                          : 'Place Order (Pay on Delivery)',
                      style: const TextStyle(fontSize: 16),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}