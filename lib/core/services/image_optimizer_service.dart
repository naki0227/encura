import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';

class ImageOptimizerService {
  static const Duration _timeout = Duration(seconds: 15);

  /// Uploads image bytes to Rust service and returns optimized bytes.
  /// Returns original bytes if optimization fails.
  static Future<Uint8List> optimizeImage(
    Uint8List imageBytes, {
    http.Client? client,
    String serviceUrl = AppConfig.imageOptimizerUrl,
  }) async {
    if (serviceUrl.isEmpty) return imageBytes;
    final httpClient = client ?? http.Client();
    try {
      if (kDebugMode) {
        print('Optimizing image: ${imageBytes.length} bytes...');
      }

      final request = http.MultipartRequest('POST', Uri.parse(serviceUrl));
      
      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          imageBytes,
          filename: 'upload.jpg',
        ),
      );

      final streamedResponse = await httpClient.send(request).timeout(_timeout);
      final response = await http.Response.fromStream(streamedResponse).timeout(_timeout);

      // A 200 is not enough: a stopped Cloud Run service answers 200 with an
      // HTML placeholder page, which must never be sent on as an image.
      final contentType = response.headers['content-type'] ?? '';
      if (response.statusCode == 200 && contentType.startsWith('image/')) {
        final optimizedBytes = response.bodyBytes;
        if (kDebugMode) {
          print('Optimization successful: ${optimizedBytes.length} bytes (Original: ${imageBytes.length})');
        }
        return optimizedBytes;
      } else {
        if (kDebugMode) {
          print('Optimization failed: ${response.statusCode} $contentType');
        }
        return imageBytes; // Fallback to original
      }
    } catch (e) {
      if (kDebugMode) {
        print('Optimization error: $e');
      }
      return imageBytes; // Fallback to original
    } finally {
      if (client == null) httpClient.close();
    }
  }
}
