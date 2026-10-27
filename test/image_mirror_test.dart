import 'package:encura/core/models/image_credit.dart';
import 'package:encura/core/utils/image_url.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mirror name matches scripts/content/mirror_images.py (SHA-1 of the stored URL)', () {
    // The same URL was copied by mirror_images.py into 56f14436….jpg.
    const url = 'http://127.0.0.1:8899/%E5%85%AD%E6%9F%BF%E5%9B%B3.jpg';
    expect(
      mirroredImageUrl(url, base: 'https://example.supabase.co/'),
      'https://example.supabase.co/storage/v1/object/public/art-images/56f14436b1ac97f99f03598f2af06696e496f960.jpg',
    );
    expect(mirroredImageUrl('', base: 'https://example.supabase.co'), isNull);
    expect(mirroredImageUrl(url, base: ''), isNull);
  });

  test('credit label names the source and the license', () {
    const pd = ImageCredit(
      imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/a/ab/X.jpg',
      license: 'Public domain',
      page: 'https://commons.wikimedia.org/wiki/File:X.jpg',
    );
    expect(pd.label, '画像：Wikimedia Commons・パブリックドメイン');
    const by = ImageCredit(imageUrl: 'https://upload.wikimedia.org/x.jpg', license: 'CC BY-SA 4.0', credit: 'Jane Doe');
    expect(by.label, '画像：Jane Doe・CC BY-SA 4.0');
    expect(by.link, 'https://upload.wikimedia.org/x.jpg');
    const old = ImageCredit(imageUrl: 'https://images.metmuseum.org/CRDImages/a.jpg');
    expect(old.label, '画像：The Metropolitan Museum of Art');
  });
}
