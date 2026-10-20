import 'package:encura/core/utils/image_url.dart';
import 'package:flutter_test/flutter_test.dart';

const base = 'https://upload.wikimedia.org/wikipedia/commons/thumb/e/ea/Starry.jpg';

void main() {
  test('moves non-standard Wikimedia widths up to an allowed one', () {
    expect(normalizeImageUrl('$base/800px-Starry.jpg'), '$base/960px-Starry.jpg');
    expect(normalizeImageUrl('$base/640px-Starry.jpg'), '$base/960px-Starry.jpg');
    expect(normalizeImageUrl('$base/1024px-Starry.jpg'), '$base/1280px-Starry.jpg');
    expect(normalizeImageUrl('$base/5000px-Starry.jpg'), '$base/3840px-Starry.jpg');
  });

  test('keeps allowed widths and drops tracking parameters only when rewriting', () {
    expect(normalizeImageUrl('$base/960px-Starry.jpg'), '$base/960px-Starry.jpg');
    expect(normalizeImageUrl('$base/800px-Starry.jpg?utm_source=x'), '$base/960px-Starry.jpg');
  });

  test('leaves other URLs alone apart from trimming and encoding', () {
    expect(normalizeImageUrl('  https://example.com/a.jpg '), 'https://example.com/a.jpg');
    expect(normalizeImageUrl('https://upload.wikimedia.org/wikipedia/commons/e/ea/Starry.jpg'),
        'https://upload.wikimedia.org/wikipedia/commons/e/ea/Starry.jpg');
    expect(normalizeImageUrl('https://example.com/星月夜.jpg'),
        'https://example.com/%E6%98%9F%E6%9C%88%E5%A4%9C.jpg');
  });
}
