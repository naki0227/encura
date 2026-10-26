import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/utils/image_url.dart';
import '../theme/tokens.dart';
import 'motion.dart';

/// Opens a full-height reading view for a news item or an artwork text:
/// the picture on top, then a quiet column of text set for reading.
Future<void> showReadingSheet(
  BuildContext context, {
  String imageUrl = '',
  String? tag,
  String? meta,
  required String title,
  String? subtitle,
  required String body,
  String? sourceUrl,
  List<Widget> actions = const [],
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Palette.wall,
    barrierColor: const Color(0xB3000000),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    clipBehavior: Clip.antiAlias,
    sheetAnimationStyle: Motion.reduced(context)
        ? AnimationStyle.noAnimation
        : const AnimationStyle(duration: Duration(milliseconds: 360), curve: Motion.curve),
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 1,
      builder: (context, controller) => _ReadingView(
        controller: controller,
        imageUrl: imageUrl,
        tag: tag,
        meta: meta,
        title: title,
        subtitle: subtitle,
        body: body,
        sourceUrl: sourceUrl,
        actions: actions,
      ),
    ),
  );
}

class _ReadingView extends StatelessWidget {
  const _ReadingView({
    required this.controller,
    required this.imageUrl,
    required this.tag,
    required this.meta,
    required this.title,
    required this.subtitle,
    required this.body,
    required this.sourceUrl,
    required this.actions,
  });

  final ScrollController controller;
  final String imageUrl;
  final String? tag;
  final String? meta;
  final String title;
  final String? subtitle;
  final String body;
  final String? sourceUrl;
  final List<Widget> actions;

  String? get _sourceHost {
    final host = Uri.tryParse(sourceUrl ?? '')?.host ?? '';
    return host.isEmpty ? null : host.replaceFirst(RegExp(r'^www\.'), '');
  }

  Future<void> _openSource(BuildContext context) async {
    final uri = Uri.tryParse(sourceUrl ?? '');
    final opened = uri != null && await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ページを開けませんでした')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final host = _sourceHost;
    return Stack(
      children: [
        ListView(
          controller: controller,
          padding: EdgeInsets.zero,
          children: [
            if (imageUrl.isNotEmpty)
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.55),
                child: Container(
                  color: Palette.room,
                  width: double.infinity,
                  child: CachedNetworkImage(
                    imageUrl: normalizeImageUrl(imageUrl),
                    httpHeaders: imageHeaders,
                    fit: BoxFit.contain,
                    fadeInCurve: Motion.curve,
                    placeholder: (context, url) => const SizedBox(height: 280),
                    errorWidget: (context, url, error) => const SizedBox(height: 24),
                  ),
                ),
              )
            else
              const SizedBox(height: 40),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (tag != null || meta != null)
                    Row(
                      children: [
                        if (tag != null) PhotoTag(tag!),
                        if (tag != null && meta != null) const SizedBox(width: 12),
                        if (meta != null)
                          Text(meta!, style: const TextStyle(color: Palette.textSub, fontSize: 12, letterSpacing: 1)),
                      ],
                    ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Palette.text,
                          fontWeight: FontWeight.w700,
                          height: 1.5,
                          letterSpacing: 0.5,
                        ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 8),
                    Text(subtitle!, style: const TextStyle(color: Palette.textSub, fontSize: 14, letterSpacing: 1)),
                  ],
                  const SizedBox(height: 20),
                  const Divider(height: 1, color: Palette.line),
                  const SizedBox(height: 20),
                  Text(
                    body,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: const Color(0xE6FFFFFF),
                          fontSize: 16,
                          height: 2.0,
                          letterSpacing: 0.6,
                        ),
                  ),
                  if (host != null) ...[
                    const SizedBox(height: 28),
                    Text('出典：$host', style: const TextStyle(color: Palette.textSub, fontSize: 12)),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _openSource(context),
                        icon: const Icon(Icons.open_in_new, size: 16),
                        label: const Text('出典の記事を読む'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Palette.text,
                          side: const BorderSide(color: Palette.line),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        ),
                      ),
                    ),
                  ],
                  for (final action in actions) ...[const SizedBox(height: 10), action],
                ],
              ),
            ),
          ],
        ),
        // Grabber and close button stay put while the text scrolls.
        Positioned(
          top: 8,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(color: const Color(0x66FFFFFF), borderRadius: BorderRadius.circular(2)),
            ),
          ),
        ),
        Positioned(
          top: 12,
          right: 12,
          child: IconButton.filled(
            tooltip: '閉じる',
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, size: 20),
            style: IconButton.styleFrom(backgroundColor: const Color(0x99000000), foregroundColor: Palette.text),
          ),
        ),
      ],
    );
  }
}
