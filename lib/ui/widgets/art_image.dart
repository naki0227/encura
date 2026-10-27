import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/image_credit.dart';
import '../../core/utils/image_url.dart';
import '../theme/tokens.dart';

/// An artwork or news image: our own copy in Supabase Storage first, then the
/// original (Wikimedia or a museum) when the copy is missing or fails.
///
/// The original is tried again after a pause, twice at most, because
/// Wikimedia throttles bursts (HTTP 429) when many thumbnails load at once.
class ArtImage extends StatefulWidget {
  const ArtImage(
    this.url, {
    super.key,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.placeholder,
    this.error,
  });

  final String url;
  final BoxFit fit;
  final double? width;
  final double? height;

  /// Shown while loading; a quiet frame-colored box by default.
  final Widget? placeholder;

  /// Shown when no source loads; the placeholder by default.
  final Widget? error;

  @override
  State<ArtImage> createState() => _ArtImageState();
}

class _ArtImageState extends State<ArtImage> {
  static const _maxRetries = 2;
  late bool _useMirror = mirroredImageUrl(widget.url) != null;
  int _attempt = 0;
  bool _retryScheduled = false;

  @override
  void didUpdateWidget(ArtImage old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url) {
      _useMirror = mirroredImageUrl(widget.url) != null;
      _attempt = 0;
      _retryScheduled = false;
    }
  }

  void _failed(String url) {
    if (_retryScheduled) return;
    if (_useMirror) {
      // No copy yet (or Storage is unreachable): go to the original now.
      _retryScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _useMirror = false;
            _retryScheduled = false;
          });
        }
      });
      return;
    }
    if (_attempt >= _maxRetries) return;
    _retryScheduled = true;
    Future.delayed(Duration(seconds: 3 * (_attempt + 1)), () async {
      await CachedNetworkImage.evictFromCache(url);
      if (!mounted) return;
      setState(() {
        _attempt++;
        _retryScheduled = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final placeholder = widget.placeholder ?? Container(color: Palette.frame, width: widget.width, height: widget.height);
    if (widget.url.isEmpty) return widget.error ?? placeholder;
    final url = _useMirror ? mirroredImageUrl(widget.url)! : normalizeImageUrl(widget.url);
    return CachedNetworkImage(
      key: ValueKey('$url#$_attempt'),
      imageUrl: url,
      httpHeaders: _useMirror ? null : imageHeaders,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      fadeInCurve: Motion.curve,
      fadeInDuration: Motion.reduced(context) ? Duration.zero : Motion.mid,
      placeholder: (context, _) => placeholder,
      errorWidget: (context, _, __) {
        _failed(url);
        return _useMirror ? placeholder : (widget.error ?? placeholder);
      },
    );
  }
}

/// "画像：Wikimedia Commons・パブリックドメイン", linking to the page that
/// describes the image and its license. Required for CC BY / CC BY-SA images.
class ImageCreditLine extends StatelessWidget {
  const ImageCreditLine(this.credit, {super.key});

  final ImageCredit credit;

  @override
  Widget build(BuildContext context) {
    if (credit.isEmpty) return const SizedBox.shrink();
    return GestureDetector(
      onTap: () {
        final uri = Uri.tryParse(credit.link);
        if (uri != null) launchUrl(uri, mode: LaunchMode.externalApplication);
      },
      child: Text(
        credit.label,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Palette.textSub, fontSize: 10, decoration: TextDecoration.underline),
      ),
    );
  }
}
