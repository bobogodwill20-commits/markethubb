// web/download_helper.dart
import 'dart:html' as html;

void downloadCSVWeb(String csvData, String fileName) {
  try {
    final blob = html.Blob([csvData], 'text/csv');
    final url = html.Url.createObjectUrl(blob);
    
    final anchor = html.document.createElement('a') as html.AnchorElement;
    anchor.href = url;
    anchor.download = fileName;
    html.document.body?.append(anchor);
    anchor.click();
    
    html.Url.revokeObjectUrl(url);
    anchor.remove();
  } catch (e) {
    // Fallback: Use data URI
    try {
      final encoded = Uri.encodeComponent(csvData);
      final dataUri = 'data:text/csv;charset=utf-8,$encoded';
      final anchor = html.document.createElement('a') as html.AnchorElement;
      anchor.href = dataUri;
      anchor.download = fileName;
      html.document.body?.append(anchor);
      anchor.click();
      anchor.remove();
    } catch (e2) {
      print('Error downloading CSV: $e2');
      rethrow;
    }
  }
}