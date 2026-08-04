import 'dart:html' as html;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;

class WebImagePicker {
  static Future<List<Uint8List>> pickImages() async {
    if (!kIsWeb) return [];
    
    final input = html.FileUploadInputElement();
    input.multiple = true;
    input.accept = 'image/*';
    input.click();
    
    await input.onChange.first;
    
    final files = input.files;
    if (files == null || files.isEmpty) return [];
    
    List<Uint8List> imageData = [];
    for (var file in files) {
      final reader = html.FileReader();
      reader.readAsArrayBuffer(file);
      await reader.onLoad.first;
      imageData.add(reader.result as Uint8List);
    }
    
    return imageData;
  }
}