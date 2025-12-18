import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class ImageOptimizerService {
  // Hardcoded for portfolio purposes. Ideally should be in .env
  static const String _serviceUrl = 'https://encura-993497231174.europe-west1.run.app/process';

  /// Uploads image bytes to Rust service and returns optimized bytes.
  /// Returns original bytes if optimization fails.
  static Future<Uint8List> optimizeImage(Uint8List imageBytes) async {
    try {
      if (kDebugMode) {
        print('Optimizing image: ${imageBytes.length} bytes...');
      }

      final request = http.MultipartRequest('POST', Uri.parse(_serviceUrl));
      
      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          imageBytes,
          filename: 'upload.jpg',
        ),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final optimizedBytes = response.bodyBytes;
        if (kDebugMode) {
          print('Optimization successful: ${optimizedBytes.length} bytes (Original: ${imageBytes.length})');
        }
        return optimizedBytes;
      } else {
        if (kDebugMode) {
          print('Optimization failed with status: ${response.statusCode}');
        }
        return imageBytes; // Fallback to original
      }
    } catch (e) {
      if (kDebugMode) {
        print('Optimization error: $e');
      }
      return imageBytes; // Fallback to original
    }
  }
}
