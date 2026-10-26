import 'package:flutter/foundation.dart' show kIsWeb;

/// Wikimedia only serves thumbnails in these widths; any other width is
/// refused with an HTML error page (https://w.wiki/GHai). Older crawler runs
/// stored 640px / 800px URLs, which stopped loading.
const wikimediaThumbWidths = [20, 40, 60, 120, 250, 330, 500, 960, 1280, 1920, 3840];

final _wikimediaThumb = RegExp(
  r'^(https://upload\.wikimedia\.org/wikipedia/[^?#]+/thumb/[^?#]+/)(\d+)px-([^/?#]+)',
);

/// Make a stored image URL loadable: trim it, percent-encode non-ASCII
/// characters, and move Wikimedia thumbnails to the nearest allowed width
/// that is not smaller than the stored one.
String normalizeImageUrl(String url) {
  var clean = url.trim();
  if (clean.contains(RegExp(r'[^\x00-\x7F]'))) {
    clean = Uri.encodeFull(clean);
  }
  final match = _wikimediaThumb.firstMatch(clean);
  if (match == null) return clean;

  final width = int.parse(match.group(2)!);
  if (wikimediaThumbWidths.contains(width)) return clean;
  final allowed = wikimediaThumbWidths.firstWhere(
    (w) => w >= width,
    orElse: () => wikimediaThumbWidths.last,
  );
  // Drop any query string: it is not part of the thumbnail path.
  return '${match.group(1)}${allowed}px-${match.group(3)}';
}

/// Request headers for artwork images. Wikimedia asks apps to identify
/// themselves with a contact address and throttles anonymous clients harder.
/// Browsers do not allow setting the User-Agent, so the web build sends none.
final Map<String, String>? imageHeaders = kIsWeb
    ? null
    : const {'User-Agent': 'EnCura/1.0.5 (+https://enludus.com; contact@enludus.com)'};
