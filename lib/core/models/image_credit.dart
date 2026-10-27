/// Where an image comes from and under which license, as stored with the
/// row (image_license, image_credit, image_page). Rows published before
/// licenses were stored have none; the source is then named from the URL.
class ImageCredit {
  final String imageUrl;
  final String? license;
  final String? credit;
  final String? page;

  const ImageCredit({required this.imageUrl, this.license, this.credit, this.page});

  factory ImageCredit.fromJson(Map<String, dynamic> json) => ImageCredit(
        imageUrl: json['image_url'] ?? '',
        license: json['image_license'],
        credit: json['image_credit'],
        page: json['image_page'],
      );

  String get _source {
    final host = Uri.tryParse(page ?? imageUrl)?.host ?? '';
    if (host.contains('wikimedia') || host.contains('wikipedia')) return 'Wikimedia Commons';
    if (host.contains('metmuseum')) return 'The Metropolitan Museum of Art';
    if (host.contains('artic.edu')) return 'The Art Institute of Chicago';
    if (host.contains('clevelandart')) return 'The Cleveland Museum of Art';
    return host.replaceFirst(RegExp(r'^www\.'), '');
  }

  String get _license {
    final l = (license ?? '').trim();
    if (l.toLowerCase().startsWith('public domain')) return 'パブリックドメイン';
    return l;
  }

  /// "画像：Wikimedia Commons・パブリックドメイン", "画像：撮影者・CC BY-SA 4.0".
  String get label {
    final who = (credit ?? '').trim().isNotEmpty ? credit!.trim() : _source;
    return ['画像：$who', if (_license.isNotEmpty) _license].join('・');
  }

  /// The page describing the image and its license.
  String get link => (page ?? '').isNotEmpty ? page! : imageUrl;

  bool get isEmpty => imageUrl.isEmpty;
}
