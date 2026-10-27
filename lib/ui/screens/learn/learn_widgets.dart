import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/models/art_knowledge.dart';
import '../../../core/utils/image_url.dart';
import '../../theme/tokens.dart';
import '../../widgets/motion.dart';
import '../chat/chat_screen.dart';
import 'artwork_screen.dart';

/// A picture from the library, quiet while it loads.
///
/// Wikimedia throttles bursts (HTTP 429) when many thumbnails load at once,
/// so a failed image is tried again after a pause, twice at most.
class KnowledgeImage extends StatefulWidget {
  const KnowledgeImage(this.url, {super.key, this.fit = BoxFit.cover});

  final String url;
  final BoxFit fit;

  @override
  State<KnowledgeImage> createState() => _KnowledgeImageState();
}

class _KnowledgeImageState extends State<KnowledgeImage> {
  static const _maxRetries = 2;
  int _attempt = 0;
  bool _retryScheduled = false;

  void _scheduleRetry(String url) {
    if (_retryScheduled || _attempt >= _maxRetries) return;
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
    if (widget.url.isEmpty) return Container(color: Palette.frame);
    final url = normalizeImageUrl(widget.url);
    return CachedNetworkImage(
      key: ValueKey(_attempt),
      imageUrl: url,
      httpHeaders: imageHeaders,
      fit: widget.fit,
      fadeInCurve: Motion.curve,
      fadeInDuration: Motion.reduced(context) ? Duration.zero : Motion.mid,
      placeholder: (context, _) => Container(color: Palette.frame),
      errorWidget: (context, _, __) {
        _scheduleRetry(url);
        return Container(color: Palette.frame);
      },
    );
  }
}

/// A small card for an artwork in horizontal rows and the library grid.
class ArtworkThumb extends StatelessWidget {
  const ArtworkThumb({super.key, required this.artwork, required this.knowledge, this.width});

  final Artwork artwork;
  final ArtKnowledge knowledge;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final meta = [artwork.artist, if (artwork.year != null) '${artwork.year}'].join('・');
    return Pressable(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ArtworkScreen(artwork: artwork, knowledge: knowledge)),
      ),
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Palette.line),
                ),
                child: KnowledgeImage(artwork.imageUrl),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              artwork.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Palette.text, fontSize: 13, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              meta,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Palette.textSub, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

/// A titled horizontal row of artworks; nothing when [works] is empty.
class ArtworkRow extends StatelessWidget {
  const ArtworkRow({super.key, required this.label, required this.title, required this.works, required this.knowledge});

  final String label;
  final String title;
  final List<Artwork> works;
  final ArtKnowledge knowledge;

  @override
  Widget build(BuildContext context) {
    if (works.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SectionHeading(label: label, title: title),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 210,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              itemCount: works.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, i) => ArtworkThumb(artwork: works[i], knowledge: knowledge, width: 132),
            ),
          ),
        ],
      ),
    );
  }
}

/// A work shown large between paragraphs, captioned like a museum label.
class ArtworkFigure extends StatelessWidget {
  const ArtworkFigure({super.key, required this.artwork, required this.knowledge});

  final Artwork artwork;
  final ArtKnowledge knowledge;

  @override
  Widget build(BuildContext context) {
    final meta = [artwork.artist, if (artwork.year != null) artwork.yearLabel].join('・');
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 30),
      child: Pressable(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ArtworkScreen(artwork: artwork, knowledge: knowledge)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 300,
              width: double.infinity,
              color: Palette.frame,
              padding: const EdgeInsets.all(12),
              child: KnowledgeImage(artwork.imageUrl, fit: BoxFit.contain),
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(artwork.title,
                          style: const TextStyle(color: Palette.text, fontSize: 14, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(meta, style: const TextStyle(color: Palette.textSub, fontSize: 12)),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Text('解説を読む', style: TextStyle(color: Palette.gold, fontSize: 11)),
                ),
                const Icon(Icons.chevron_right, size: 18, color: Palette.gold),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Body text set for reading; paragraphs come separated by blank lines.
///
/// With [figures], a work goes in after each paragraph but the last, so the
/// text reads beside the pictures it talks about.
class ReadingText extends StatelessWidget {
  const ReadingText(this.text, {super.key, this.figures = const [], this.knowledge});

  final String text;
  final List<Artwork> figures;
  final ArtKnowledge? knowledge;

  @override
  Widget build(BuildContext context) {
    final paragraphs = text.split(RegExp(r'\n\s*\n')).where((p) => p.trim().isNotEmpty).toList();
    final k = knowledge;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, p) in paragraphs.indexed) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Text(
              p.trim(),
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: const Color(0xE6FFFFFF),
                    fontSize: 16,
                    height: 2.0,
                    letterSpacing: 0.6,
                  ),
            ),
          ),
          if (k != null && i < figures.length && i < paragraphs.length - 1)
            ArtworkFigure(artwork: figures[i], knowledge: k),
        ],
      ],
    );
  }
}

/// Opens the curator with a question already asked.
void askCurator(BuildContext context, String question) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => ChatScreen(initialQuestion: question)),
  );
}

class AskCuratorButton extends StatelessWidget {
  const AskCuratorButton({super.key, required this.question});

  final String question;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => askCurator(context, question),
        icon: const Icon(Icons.chat_bubble_outline, size: 18),
        label: const Text('学芸員に聞く'),
        style: OutlinedButton.styleFrom(
          foregroundColor: Palette.gold,
          side: const BorderSide(color: Palette.gold),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
      ),
    );
  }
}

/// "出典：ja.wikipedia.org", opening the page.
class SourceLink extends StatelessWidget {
  const SourceLink(this.url, {super.key});

  final String url;

  @override
  Widget build(BuildContext context) {
    final uri = Uri.tryParse(url);
    final host = (uri?.host ?? '').replaceFirst(RegExp(r'^www\.'), '');
    if (uri == null || host.isEmpty) return const SizedBox.shrink();
    return GestureDetector(
      onTap: () => launchUrl(uri, mode: LaunchMode.externalApplication),
      child: Text(
        '出典：$host',
        style: const TextStyle(color: Palette.textSub, fontSize: 12, decoration: TextDecoration.underline),
      ),
    );
  }
}
