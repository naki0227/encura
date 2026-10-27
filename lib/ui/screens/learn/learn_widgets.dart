import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/app_config.dart';
import '../../../core/models/art_knowledge.dart';
import '../../../core/services/event_service.dart';
import '../../../core/services/exhibitions_store.dart';
import '../../../core/utils/exhibition_match.dart';
import '../../theme/tokens.dart';
import '../../widgets/art_image.dart';
import '../../widgets/motion.dart';
import '../chat/chat_screen.dart';
import '../event/event_detail_screen.dart';
import 'artist_screen.dart';
import 'artwork_screen.dart';

/// A picture from the library, quiet while it loads.
class KnowledgeImage extends StatelessWidget {
  const KnowledgeImage(this.url, {super.key, this.fit = BoxFit.cover});

  final String url;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) => ArtImage(url, fit: fit);
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

void openArtist(BuildContext context, String name, ArtKnowledge knowledge) {
  Navigator.push(context, MaterialPageRoute(builder: (_) => ArtistScreen(name: name, knowledge: knowledge)));
}

/// An artist as a round picture of their work, with name and years.
class ArtistAvatar extends StatelessWidget {
  const ArtistAvatar({super.key, required this.name, required this.knowledge, this.size = 72});

  final String name;
  final ArtKnowledge knowledge;
  final double size;

  @override
  Widget build(BuildContext context) {
    final from = knowledge.activeFrom(name);
    final profile = knowledge.artist(name);
    final years = profile != null && profile.lifeLabel.isNotEmpty ? profile.lifeLabel : (from == null ? '' : '$from年ごろ');
    return Pressable(
      onTap: () => openArtist(context, name, knowledge),
      child: SizedBox(
        width: size + 20,
        child: Column(
          children: [
            Container(
              width: size,
              height: size,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Palette.frame,
                border: Border.all(color: Palette.line),
              ),
              child: _ArtistFace(name: name, knowledge: knowledge),
            ),
            const SizedBox(height: 8),
            Text(
              name,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Palette.text, fontSize: 11, fontWeight: FontWeight.w700, height: 1.4),
            ),
            if (years.isNotEmpty)
              Text(years, style: const TextStyle(color: Palette.textSub, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

/// A work of the artist, or their initial when none is in the library.
class _ArtistFace extends StatelessWidget {
  const _ArtistFace({required this.name, required this.knowledge});

  final String name;
  final ArtKnowledge knowledge;

  @override
  Widget build(BuildContext context) {
    final cover = knowledge.coverOfArtist(name);
    if (cover.isNotEmpty) return KnowledgeImage(cover);
    final parts = name.split(RegExp(r'[・＝=]'));
    return Center(
      child: Text(
        parts.last.characters.first,
        style: const TextStyle(color: Palette.gold, fontSize: 24, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// A titled horizontal row of artists; nothing when [names] is empty.
class ArtistRow extends StatelessWidget {
  const ArtistRow({
    super.key,
    required this.label,
    required this.title,
    required this.names,
    required this.knowledge,
    this.trailing,
  });

  final String label;
  final String title;
  final List<String> names;
  final ArtKnowledge knowledge;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    if (names.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SectionHeading(label: label, title: title, trailing: trailing),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 136,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              itemCount: names.length,
              separatorBuilder: (_, __) => const SizedBox(width: 4),
              itemBuilder: (context, i) => ArtistAvatar(name: names[i], knowledge: knowledge),
            ),
          ),
        ],
      ),
    );
  }
}

/// Exhibitions that name any of [keys], each marked 開催中 / これから / 終了.
/// Shows nothing until loaded, and nothing when none match.
class ExhibitionsSection extends StatelessWidget {
  const ExhibitionsSection({super.key, required this.keys, required this.title});

  final List<String> keys;
  final String title;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ArtEvent>>(
      future: ExhibitionsStore.instance.load(),
      builder: (context, snapshot) {
        final today = DateTime.now();
        final hits = exhibitionsNaming(snapshot.data ?? const [], keys, today);
        if (hits.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 36, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeading(label: 'Exhibitions', title: title),
              const SizedBox(height: 14),
              for (final e in hits) _ExhibitionTile(event: e, status: statusOf(e, today)),
            ],
          ),
        );
      },
    );
  }
}

class _ExhibitionTile extends StatelessWidget {
  const _ExhibitionTile({required this.event, required this.status});

  final ArtEvent event;
  final ExhibitionStatus status;

  static String _md(DateTime d) => '${d.month}/${d.day}';

  @override
  Widget build(BuildContext context) {
    final (label, note) = switch (status) {
      ExhibitionStatus.running => ('開催中', '${_md(event.endDate)}まで'),
      ExhibitionStatus.upcoming => ('これから', '${_md(event.startDate)}から'),
      ExhibitionStatus.ended => ('終了', '${event.endDate.year}/${_md(event.endDate)}に終了'),
    };
    final ended = status == ExhibitionStatus.ended;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Pressable(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EventDetailScreen(event: event))),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Palette.frame,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Palette.line),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                padding: const EdgeInsets.symmetric(vertical: 4),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: status == ExhibitionStatus.running ? Palette.gold : Colors.transparent,
                  borderRadius: BorderRadius.circular(2),
                  border: Border.all(color: ended ? Palette.line : Palette.gold),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: switch (status) {
                      ExhibitionStatus.running => Palette.room,
                      ExhibitionStatus.upcoming => Palette.gold,
                      ExhibitionStatus.ended => Palette.textSub,
                    },
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: ended ? Palette.textSub : Palette.text,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('${event.venue}・$note', style: const TextStyle(color: Palette.textSub, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "所蔵：ルーヴル美術館　地図で見る", opening the museum in Maps.
class CollectionLink extends StatelessWidget {
  const CollectionLink(this.collection, {super.key});

  final String collection;

  @override
  Widget build(BuildContext context) {
    final uri = Uri.https('maps.apple.com', '/', {'q': collection});
    return Pressable(
      onTap: () => launchUrl(uri, mode: LaunchMode.externalApplication),
      child: Row(
        children: [
          const Icon(Icons.place_outlined, size: 14, color: Palette.textSub),
          const SizedBox(width: 4),
          Flexible(
            child: Text('所蔵：$collection', style: const TextStyle(color: Palette.textSub, fontSize: 12)),
          ),
          const SizedBox(width: 8),
          const Text('地図で見る', style: TextStyle(color: Palette.gold, fontSize: 11)),
          const Icon(Icons.chevron_right, size: 16, color: Palette.gold),
        ],
      ),
    );
  }
}

/// "画集を探す" on Amazon, with the Associates disclosure. Hidden unless the
/// build sets AMAZON_ASSOCIATE_TAG.
class BookLink extends StatelessWidget {
  const BookLink({super.key, required this.query, required this.label});

  final String query;
  final String label;

  @override
  Widget build(BuildContext context) {
    const tag = AppConfig.amazonAssociateTag;
    if (tag.isEmpty) return const SizedBox.shrink();
    final uri = Uri.https('www.amazon.co.jp', '/s', {'k': query, 'i': 'stripbooks', 'tag': tag});
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutlinedButton.icon(
            onPressed: () => launchUrl(uri, mode: LaunchMode.externalApplication),
            icon: const Icon(Icons.menu_book_outlined, size: 18),
            label: Text(label),
            style: OutlinedButton.styleFrom(
              foregroundColor: Palette.text,
              side: const BorderSide(color: Palette.line),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Amazonのアソシエイトとして、EnCuraは適格販売により収入を得ています。',
            style: TextStyle(color: Palette.textSub, fontSize: 10),
          ),
        ],
      ),
    );
  }
}
