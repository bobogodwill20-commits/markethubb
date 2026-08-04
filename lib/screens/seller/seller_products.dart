import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../services/storage_service.dart';
import '../../widgets/common/product_image.dart';
import '../../config/supabase.dart';

class SellerProductsScreen extends StatefulWidget {
  const SellerProductsScreen({super.key});

  @override
  State<SellerProductsScreen> createState() => _SellerProductsScreenState();
}

class _SellerProductsScreenState extends State<SellerProductsScreen> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _products = [];
  bool _isLoading = true;
  bool _isAddingProduct = false;
  bool _isEditingProduct = false;
  String _editingProductId = '';
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Form controllers
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController();
  final _categoryController = TextEditingController();
  
  List<XFile> _selectedImages = [];
  List<String> _existingImages = [];
  File? _selectedVideo;
  String? _videoUrl;
  List<String> _imageUrls = [];
  List<String> _imagesToDelete = [];

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
    _fetchProducts();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _fetchProducts() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      
      final response = await Supabase.instance.client
          .from('products')
          .select()
          .eq('seller_id', user.id)
          .order('created_at', ascending: false);
      
      if (mounted) {
        setState(() {
          _products = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching products: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error fetching products: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickImages() async {
    try {
      final picker = ImagePicker();
      final List<XFile> images = await picker.pickMultiImage();
      
      if (images.isNotEmpty) {
        if (mounted) {
          setState(() {
            _selectedImages.addAll(images);
          });
        }
      }
    } catch (e) {
      print('Error picking images: $e');
    }
  }

  Future<void> _pickVideo() async {
    try {
      final picker = ImagePicker();
      final XFile? video = await picker.pickVideo(source: ImageSource.gallery);
      
      if (video != null) {
        if (mounted) {
          setState(() {
            _selectedVideo = File(video.path);
          });
        }
      }
    } catch (e) {
      print('Error picking video: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting video: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _uploadImages() async {
    if (_selectedImages.isEmpty) return;
    
    try {
      if (mounted) {
        setState(() => _isAddingProduct = true);
      }
      
      final urls = await StorageService.uploadImages(_selectedImages);
      
      if (mounted) {
        setState(() {
          _imageUrls.addAll(urls.where((url) => !url.startsWith('placeholder_')));
        });
      }
      
      // Show warning if all images failed
      if (urls.every((url) => url.startsWith('placeholder_'))) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Images will be added as placeholders. Please check storage configuration.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      print('⚠️ Error uploading images: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading images: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
        // Add placeholders so product can still be created
        for (var i = 0; i < _selectedImages.length; i++) {
          _imageUrls.add('placeholder_${DateTime.now().millisecondsSinceEpoch}_$i');
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isAddingProduct = false);
      }
    }
  }

  Future<void> _uploadVideo() async {
    if (_selectedVideo == null) return;
    
    try {
      final url = await StorageService.uploadImage(_selectedVideo!);
      if (mounted) {
        setState(() {
          if (!url.startsWith('placeholder_')) {
            _videoUrl = url;
          }
        });
      }
    } catch (e) {
      print('⚠️ Error uploading video: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading video: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteImages(List<String> imageUrls) async {
    if (imageUrls.isEmpty) return;
    try {
      await StorageService.deleteImages(imageUrls);
    } catch (e) {
      print('Error deleting images: $e');
    }
  }

  Future<void> _addProduct() async {
    if (_nameController.text.isEmpty || _priceController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill required fields')),
      );
      return;
    }

    if (mounted) {
      setState(() => _isAddingProduct = true);
    }
    
    try {
      // Handle images
      if (_selectedImages.isNotEmpty) {
        await _uploadImages();
      }
      
      // If no images, add placeholder
      if (_imageUrls.isEmpty) {
        _imageUrls.add('placeholder_${DateTime.now().millisecondsSinceEpoch}');
      }
      
      // Upload video if selected
      if (_selectedVideo != null) {
        await _uploadVideo();
      }
      
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please login to add products')),
        );
        return;
      }
      
      await Supabase.instance.client.from('products').insert({
        'seller_id': user.id,
        'name': _nameController.text,
        'description': _descriptionController.text,
        'price': double.parse(_priceController.text),
        'stock': int.parse(_stockController.text),
        'category': _categoryController.text,
        'images': _imageUrls,
        'video_url': _videoUrl,
        'status': 'active',
        'created_at': DateTime.now().toIso8601String(),
      });
      
      _resetForm();
      _fetchProducts();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product added successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding product: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isAddingProduct = false);
        Navigator.pop(context);
      }
    }
  }

  Future<void> _editProduct() async {
    if (_nameController.text.isEmpty || _priceController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill required fields')),
      );
      return;
    }

    if (mounted) {
      setState(() => _isEditingProduct = true);
    }
    
    try {
      // Upload new images
      if (_selectedImages.isNotEmpty) {
        await _uploadImages();
      }
      
      // Upload new video
      if (_selectedVideo != null) {
        await _uploadVideo();
      }
      
      // Delete removed images
      if (_imagesToDelete.isNotEmpty) {
        await _deleteImages(_imagesToDelete);
      }
      
      final allImages = [..._existingImages, ..._imageUrls];
      
      await Supabase.instance.client
          .from('products')
          .update({
            'name': _nameController.text,
            'description': _descriptionController.text,
            'price': double.parse(_priceController.text),
            'stock': int.parse(_stockController.text),
            'category': _categoryController.text,
            'images': allImages.isEmpty ? ['placeholder_${DateTime.now().millisecondsSinceEpoch}'] : allImages,
            'video_url': _videoUrl,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', _editingProductId);
      
      _resetForm();
      _fetchProducts();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product updated successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating product: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isEditingProduct = false);
        Navigator.pop(context);
      }
    }
  }

  void _resetForm() {
    _nameController.clear();
    _descriptionController.clear();
    _priceController.clear();
    _stockController.clear();
    _categoryController.clear();
    _selectedImages.clear();
    _existingImages.clear();
    _selectedVideo = null;
    _imageUrls.clear();
    _videoUrl = null;
    _imagesToDelete.clear();
    _editingProductId = '';
  }

  void _editProductDialog(Map<String, dynamic> product) {
    _editingProductId = product['id'] ?? '';
    _nameController.text = product['name'] ?? '';
    _descriptionController.text = product['description'] ?? '';
    _priceController.text = product['price']?.toString() ?? '';
    _stockController.text = product['stock']?.toString() ?? '';
    _categoryController.text = product['category'] ?? '';
    _existingImages = List<String>.from(product['images'] ?? []);
    _videoUrl = product['video_url'];
    _imageUrls.clear();
    _selectedImages.clear();
    _imagesToDelete.clear();
    
    _showProductDialog(isEditing: true);
  }

  void _showAddProductDialog() {
    _resetForm();
    _showProductDialog(isEditing: false);
  }

  void _showProductDialog({required bool isEditing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => StatefulBuilder(
          builder: (context, setState) => SingleChildScrollView(
            controller: scrollController,
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 24,
                right: 24,
                top: 24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Text(
                      isEditing ? 'Edit Product' : 'Add New Product',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Images Section
                  const Text('Product Images', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  
                  // Existing Images
                  if (isEditing && _existingImages.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      children: _existingImages.map((url) {
                        final isPlaceholder = url.startsWith('placeholder_');
                        return Stack(
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              margin: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                color: Colors.grey.shade200,
                              ),
                              child: isPlaceholder
                                  ? const Center(
                                      child: Icon(Icons.image, size: 30, color: Colors.grey),
                                    )
                                  : ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: CachedNetworkImage(
                                        imageUrl: url,
                                        fit: BoxFit.cover,
                                        placeholder: (context, _) => const Center(
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        ),
                                        errorWidget: (context, _, __) => const Icon(
                                          Icons.broken_image,
                                          size: 30,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ),
                            ),
                            Positioned(
                              right: 0,
                              top: 0,
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _imagesToDelete.add(url);
                                    _existingImages.remove(url);
                                  });
                                },
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close, size: 16, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  
                  // New Images
                  Wrap(
                    spacing: 8,
                    children: [
                      ..._selectedImages.map((image) {
                        return Stack(
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              margin: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                image: DecorationImage(
                                  image: FileImage(File(image.path)),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Positioned(
                              right: 0,
                              top: 0,
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedImages.remove(image);
                                  });
                                },
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close, size: 16, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        );
                      }),
                      if (_selectedImages.length + _existingImages.length < 5)
                        GestureDetector(
                          onTap: _pickImages,
                          child: Container(
                            width: 80,
                            height: 80,
                            margin: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.add_photo_alternate, size: 30),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Video Section
                  const Text('Product Video (Optional)', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (_selectedVideo != null)
                    Container(
                      height: 100,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.black,
                      ),
                      child: Stack(
                        children: [
                          Center(
                            child: Icon(Icons.play_circle_filled, size: 50, color: Colors.white.withOpacity(0.7)),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedVideo = null;
                                });
                              },
                              child: Container(
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close, size: 20, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (_videoUrl != null)
                    Container(
                      height: 100,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.black,
                      ),
                      child: Stack(
                        children: [
                          Center(
                            child: Icon(Icons.play_circle_filled, size: 50, color: Colors.white.withOpacity(0.7)),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _videoUrl = null;
                                });
                              },
                              child: Container(
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close, size: 20, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    GestureDetector(
                      onTap: _pickVideo,
                      child: Container(
                        height: 100,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.videocam, size: 40),
                            SizedBox(height: 8),
                            Text('Tap to upload video'),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  
                  // Product Details
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Product Name *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _descriptionController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _priceController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Price (XAF) *',
                            prefixText: 'XAF ',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: _stockController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Stock *',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _categoryController,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (_isAddingProduct || _isEditingProduct) ? null : 
                          (isEditing ? _editProduct : _addProduct),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.blue.shade600,
                      ),
                      child: (_isAddingProduct || _isEditingProduct)
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(isEditing ? 'Update Product' : 'Add Product'),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _updateStock(String productId, int newStock) async {
    if (newStock < 0) return;
    
    await Supabase.instance.client
        .from('products')
        .update({'stock': newStock, 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', productId);
    
    _fetchProducts();
  }

  Future<void> _deleteProduct(String productId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Product'),
        content: const Text('Are you sure you want to delete this product?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      final product = _products.firstWhere((p) => p['id'] == productId);
      final images = List<String>.from(product['images'] ?? []);
      
      await Supabase.instance.client
          .from('products')
          .delete()
          .eq('id', productId);
      
      if (images.isNotEmpty) {
        await _deleteImages(images);
      }
      
      _fetchProducts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product deleted!')),
        );
      }
    }
  }

  String _getProductImage(Map<String, dynamic> product) {
    if (product['images'] != null && product['images'] is List && product['images'].isNotEmpty) {
      final image = product['images'][0];
      if (image != null && 
          image.toString().isNotEmpty && 
          !image.toString().startsWith('placeholder_') &&
          (image.toString().startsWith('http://') || image.toString().startsWith('https://'))) {
        return image.toString();
      }
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isMobile = MediaQuery.of(context).size.width < 600;
    
    return Scaffold(
      backgroundColor: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('My Products'),
        backgroundColor: isDark ? Colors.grey.shade800 : Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.add, color: isDark ? Colors.white : Colors.grey.shade700),
            onPressed: _showAddProductDialog,
          ),
          IconButton(
            icon: AnimatedRotation(
              duration: const Duration(milliseconds: 500),
              turns: _isLoading ? 1.0 : 0.0,
              child: Icon(Icons.refresh, color: isDark ? Colors.white : Colors.grey.shade700),
            ),
            onPressed: _fetchProducts,
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
          : _products.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inventory_2_outlined, 
                        size: 80, 
                        color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No products yet',
                        style: TextStyle(
                          fontSize: 18, 
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap the + button to add your first product',
                        style: TextStyle(
                          color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                )
              : FadeTransition(
                  opacity: _fadeAnimation,
                  child: GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: isMobile ? 2 : 3,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 0.7,
                    ),
                    itemCount: _products.length,
                    itemBuilder: (context, index) {
                      final product = _products[index];
                      final imageUrl = _getProductImage(product);
                      
                      return TweenAnimationBuilder(
                        tween: Tween<double>(begin: 0, end: 1),
                        duration: Duration(milliseconds: 300 + (index * 50)),
                        curve: Curves.easeOut,
                        builder: (context, value, child) {
                          return Opacity(
                            opacity: value,
                            child: Transform.scale(
                              scale: 0.9 + (0.1 * value),
                              child: child,
                            ),
                          );
                        },
                        child: Container(
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
                              // Product Image with Edit Button - using Stack properly
                              Expanded(
                                flex: 2,
                                child: Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                      child: ProductImage(
                                        imageUrl: imageUrl,
                                        height: double.infinity,
                                        width: double.infinity,
                                      ),
                                    ),
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.6),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: IconButton(
                                          icon: const Icon(Icons.edit, color: Colors.white, size: 18),
                                          onPressed: () => _editProductDialog(product),
                                          padding: const EdgeInsets.all(4),
                                          constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                                        ),
                                      ),
                                    ),
                                    if (product['stock'] != null && product['stock'] < 5)
                                      Positioned(
                                        top: 8,
                                        left: 8,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.red,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Text(
                                            'Low Stock',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 9,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              // Product Info
                              Expanded(
                                flex: 3,
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        product['name'] ?? '',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: isDark ? Colors.white : Colors.grey.shade900,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${product['price']} XAF',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: Colors.blue.shade700,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.inventory, 
                                            size: 14, 
                                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Stock: ${product['stock']}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Container(
                                              decoration: BoxDecoration(
                                                border: Border.all(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Row(
                                                children: [
                                                  IconButton(
                                                    icon: Icon(Icons.remove, size: 16, color: isDark ? Colors.white : Colors.grey.shade700),
                                                    onPressed: () {
                                                      if (product['stock'] > 0) {
                                                        _updateStock(product['id'], product['stock'] - 1);
                                                      }
                                                    },
                                                    padding: EdgeInsets.zero,
                                                    constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                                                  ),
                                                  Expanded(
                                                    child: Text(
                                                      product['stock'].toString(),
                                                      textAlign: TextAlign.center,
                                                      style: TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        color: isDark ? Colors.white : Colors.grey.shade900,
                                                      ),
                                                    ),
                                                  ),
                                                  IconButton(
                                                    icon: Icon(Icons.add, size: 16, color: isDark ? Colors.white : Colors.grey.shade700),
                                                    onPressed: () {
                                                      _updateStock(product['id'], product['stock'] + 1);
                                                    },
                                                    padding: EdgeInsets.zero,
                                                    constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          IconButton(
                                            icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                            onPressed: () => _deleteProduct(product['id']),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
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
                      );
                    },
                  ),
                ),
    );
  }
}