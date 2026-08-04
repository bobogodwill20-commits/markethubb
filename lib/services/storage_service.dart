import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cross_file/cross_file.dart';

class StorageService {
  static final supabase = Supabase.instance.client;
  static const String _bucketName = 'product_images';
  static bool _bucketInitialized = false;
  static bool _bucketExists = false;
  static bool _isWeb = kIsWeb;

  static Future<void> initializeBucket() async {
    if (_bucketInitialized) return;
    
    try {
      print('🔍 Checking if bucket exists...');
      print('🌐 Platform: ${_isWeb ? "Web" : "Mobile/Desktop"}');
      
      if (_isWeb) {
        // On web, assume bucket exists since we verified it manually
        print('🌐 Web platform - assuming bucket exists (verified manually)');
        _bucketExists = true;
      } else {
        // On mobile/desktop, check normally
        final buckets = await supabase.storage.listBuckets();
        print('📦 Available buckets: ${buckets.map((b) => b.name).toList()}');
        _bucketExists = buckets.any((b) => b.name == _bucketName);
        
        if (_bucketExists) {
          print('✅ Bucket $_bucketName exists!');
        } else {
          print('❌ Bucket $_bucketName NOT found');
        }
      }
      
      _bucketInitialized = true;
    } catch (e) {
      print('⚠️ Error checking bucket: $e');
      // On web, continue with bucket assumption
      if (_isWeb) {
        print('🌐 Web error - continuing with bucket assumption');
        _bucketExists = true;
      } else {
        _bucketExists = false;
      }
      _bucketInitialized = true;
    }
  }

  static Future<bool> checkBucketExists() async {
    try {
      if (_isWeb) return true; // Assume exists on web
      final buckets = await supabase.storage.listBuckets();
      return buckets.any((bucket) => bucket.name == _bucketName);
    } catch (e) {
      return _isWeb ? true : false;
    }
  }

  static Future<List<String>> uploadImages(List<dynamic> images) async {
    if (images.isEmpty) return [];
    
    if (!_bucketInitialized) {
      await initializeBucket();
    }
    
    // On web, always try to upload regardless of bucket check
    List<String> urls = [];
    
    for (var image in images) {
      try {
        final url = await uploadImage(image);
        if (url.startsWith('http')) {
          urls.add(url);
        } else {
          urls.add('placeholder_${DateTime.now().millisecondsSinceEpoch}');
        }
      } catch (e) {
        print('⚠️ Upload error for image: $e');
        urls.add('placeholder_${DateTime.now().millisecondsSinceEpoch}');
      }
    }
    
    return urls;
  }

  static Future<String> uploadImage(dynamic image) async {
    try {
      // Always try to upload - don't check bucket existence
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${Uuid().v4()}';
      
      if (_isWeb) {
        return await _uploadImageWeb(image, fileName);
      } else {
        return await _uploadImageMobile(image, fileName);
      }
    } catch (e) {
      print('⚠️ Upload error: $e');
      return 'placeholder_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  static Future<String> _uploadImageWeb(dynamic image, String fileName) async {
    try {
      Uint8List imageBytes;
      String extension = 'png';
      
      if (image is File) {
        imageBytes = await image.readAsBytes();
        extension = image.path.split('.').last;
      } else if (image is XFile) {
        imageBytes = await image.readAsBytes();
        extension = image.path.split('.').last;
      } else if (image is String) {
        if (image.startsWith('data:image')) {
          final parts = image.split(',');
          final base64Data = parts.length > 1 ? parts[1] : '';
          imageBytes = base64Decode(base64Data) as Uint8List;
          extension = 'png';
        } else {
          try {
            final file = File(image);
            imageBytes = await file.readAsBytes();
            extension = image.split('.').last;
          } catch (e) {
            return 'placeholder_${DateTime.now().millisecondsSinceEpoch}';
          }
        }
      } else {
        return 'placeholder_${DateTime.now().millisecondsSinceEpoch}';
      }
      
      final fullFileName = '$fileName.$extension';
      
      await supabase.storage
          .from(_bucketName)
          .uploadBinary(fullFileName, imageBytes);
      
      final publicUrl = supabase.storage
          .from(_bucketName)
          .getPublicUrl(fullFileName);
      
      print('✅ Web upload successful: $publicUrl');
      return publicUrl;
    } catch (e) {
      print('⚠️ Web upload error: $e');
      return 'placeholder_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  static Future<String> _uploadImageMobile(dynamic image, String fileName) async {
    try {
      File file;
      String extension = 'png';
      
      if (image is File) {
        file = image;
        extension = image.path.split('.').last;
      } else if (image is XFile) {
        file = File(image.path);
        extension = image.path.split('.').last;
      } else if (image is String) {
        try {
          file = File(image);
          extension = image.split('.').last;
        } catch (e) {
          return 'placeholder_${DateTime.now().millisecondsSinceEpoch}';
        }
      } else {
        return 'placeholder_${DateTime.now().millisecondsSinceEpoch}';
      }
      
      final fullFileName = '$fileName.$extension';
      
      await supabase.storage
          .from(_bucketName)
          .upload(fullFileName, file);
      
      final publicUrl = supabase.storage
          .from(_bucketName)
          .getPublicUrl(fullFileName);
      
      print('✅ Mobile/Desktop upload successful: $publicUrl');
      return publicUrl;
    } catch (e) {
      print('⚠️ Mobile/Desktop upload error: $e');
      return 'placeholder_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  static Future<void> deleteImage(String imageUrl) async {
    try {
      if (imageUrl.startsWith('placeholder_')) return;
      
      final uri = Uri.parse(imageUrl);
      final fileName = uri.pathSegments.last;
      
      await supabase.storage
          .from(_bucketName)
          .remove([fileName]);
      
      print('🗑️ Deleted: $fileName');
    } catch (e) {
      print('⚠️ Delete error: $e');
    }
  }

  static Future<void> deleteImages(List<String> imageUrls) async {
    for (var url in imageUrls) {
      if (!url.startsWith('placeholder_')) {
        await deleteImage(url);
      }
    }
  }
}