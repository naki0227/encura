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
class KnowledgeImage extends StatelessWidget {
  const KnowledgeImage(this.url, {super.key, this.fit = BoxFit.cover});

  final String url;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) return Container(color: Palette.frame);
    return CachedNetworkImage(
      imageUrl: normalizeImageUrl(url),
      fit: fit,
      fadeInCurve: Motion.curve,
      fadeInDuration: Motion.reduced(context) ? Duration.zero : Motion.mid,
      placeholder: (context, _) => Container(color: Palette.frame),
      errorWidget: (context, _, __) => Container(color: Palette.frame),
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

/// Body text set for reading; paragraphs come separated by blank lines.
class ReadingText extends StatelessWidget {
  const ReadingText(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final paragraphs = text.split(RegExp(r'\n\s*\n')).where((p) => p.trim().isNotEmpty);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final p in paragraphs)
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
