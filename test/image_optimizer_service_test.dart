import 'dart:typed_data';

import 'package:encura/core/services/image_optimizer_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  final original = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0x01, 0x02]);
  const url = 'https://optimizer.example/process';

  test('returns the optimized bytes when the service answers with an image', () async {
    final optimized = [0xFF, 0xD8, 0x09];
    final client = MockClient((_) async =>
        http.Response.bytes(optimized, 200, headers: {'content-type': 'image/jpeg'}));

    final result = await ImageOptimizerService.optimizeImage(original, client: client, serviceUrl: url);

    expect(result, optimized);
  });

  test('keeps the original when the service answers 200 with an HTML page', () async {
    final client = MockClient((_) async => http.Response(
        '<!doctype html><title>Placeholder | Cloud Run</title>', 200,
        headers: {'content-type': 'text/html; charset=utf-8'}));

    final result = await ImageOptimizerService.optimizeImage(original, client: client, serviceUrl: url);

    expect(result, original);
  });

  test('keeps the original when the service fails', () async {
    final client = MockClient((_) async => throw http.ClientException('down'));

    final result = await ImageOptimizerService.optimizeImage(original, client: client, serviceUrl: url);

    expect(result, original);
  });

  test('skips the request when no service URL is configured', () async {
    var called = false;
    final client = MockClient((_) async {
      called = true;
      return http.Response('', 500);
    });

    final result = await ImageOptimizerService.optimizeImage(original, client: client, serviceUrl: '');

    expect(result, original);
    expect(called, isFalse);
  });
}
