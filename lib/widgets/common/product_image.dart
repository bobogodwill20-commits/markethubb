import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

class ProductImage extends StatelessWidget {
  final String? imageUrl;
  final double height;
  final double width;
  final BoxFit fit;
  final bool showPlaceholder;

  const ProductImage({
    super.key,
    this.imageUrl,
    this.height = 150,
    this.width = double.infinity,
    this.fit = BoxFit.cover,
    this.showPlaceholder = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Check if image URL is valid
    final isValidUrl = imageUrl != null && 
        imageUrl!.isNotEmpty && 
        !imageUrl!.startsWith('placeholder_') &&
        (imageUrl!.startsWith('http://') || imageUrl!.startsWith('https://'));

    if (isValidUrl) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: CachedNetworkImage(
          imageUrl: imageUrl!,
          height: height,
          width: width,
          fit: fit,
          placeholder: (context, url) => Container(
            height: height,
            width: width,
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
            child: Center(
              child: SpinKitFadingCircle(
                color: Colors.blue.shade700,
                size: 30,
              ),
            ),
          ),
          errorWidget: (context, url, error) => _buildPlaceholder(isDark),
        ),
      );
    } else {
      return _buildPlaceholder(isDark);
    }
  }

  Widget _buildPlaceholder(bool isDark) {
    return Container(
      height: height,
      width: width,
      color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image_outlined,
            size: 50,
            color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
          ),
          if (showPlaceholder) ...[
            const SizedBox(height: 8),
            Text(
              'No Image',
              style: TextStyle(
                color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}