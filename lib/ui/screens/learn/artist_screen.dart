import 'package:flutter/material.dart';

import '../../../core/models/art_knowledge.dart';
import '../../../core/utils/exhibition_match.dart';
import '../../theme/tokens.dart';
import '../../widgets/motion.dart';
import 'learn_widgets.dart';
import 'movement_screen.dart';

/// One artist: their life, the movements they belonged to, all their works
/// in the library, who painted at the same time, and where to see them.
class ArtistScreen extends StatelessWidget {
  const ArtistScreen({super.key, required this.name, required this.knowledge});

  final String name;
  final ArtKnowledge knowledge;

  @override
  Widget build(BuildContext context) {
    final profile = knowledge.artist(name);
    final works = knowledge.byArtist(name)..sort((a, b) => (a.year ?? 99999).compareTo(b.year ?? 99999));
    final cover = works.isEmpty ? '' : works.first.imageUrl;
    final movements = knowledge.movementsOf(name);
    final region = knowledge.regionOf(name);
    final from = knowledge.activeFrom(name);
    final years = profile != null && profile.lifeLabel.isNotEmpty
        ? profile.lifeLabel
        : (from == null ? '' : '$from年ごろの作品');
    final keys = artistKeys(name, profile);
    final callName = profile?.shortName ?? name;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: cover.isEmpty ? null : 300,
            backgroundColor: Palette.room,
            title: Text(name),
            flexibleSpace: cover.isEmpty
                ? null
                : FlexibleSpaceBar(
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        KnowledgeImage(cover),
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0x99000000), Colors.transparent, Color(0xF20E0F0E)],
                              stops: [0, 0.4, 1],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (region != null) ...[
                        PhotoTag(Movement.regionLabels[region] ?? region),
                        const SizedBox(width: 12),
                      ],
                      Text(years, style: const TextStyle(color: Palette.textSub, fontSize: 12, letterSpacing: 1)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    name,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: Palette.text,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                        ),
                  ),
                  if ((profile?.nameEn ?? '').isNotEmpty)
                    Text(profile!.nameEn.toUpperCase(),
                        style: const TextStyle(
                            fontFamily: 'Helvetica', color: Palette.gold, fontSize: 11, letterSpacing: 2.4)),
                  if (movements.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [for (final m in movements) _MovementChip(movement: m, knowledge: knowledge)],
                    ),
                  ],
                  const SizedBox(height: 20),
                  if (profile != null) ...[
                    Text(profile.summary,
                        style: const TextStyle(
                            color: Palette.text, fontSize: 15, height: 1.8, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 20),
                    const Divider(height: 1, color: Palette.line),
                    const SizedBox(height: 20),
                    // The cover is the first work; the next ones sit between paragraphs.
                    ReadingText(profile.body, figures: works.skip(1).toList(), knowledge: knowledge),
                    SourceLink(profile.sourceUrl),
                  ] else if (works.isNotEmpty)
                    Text(
                      'ライブラリにある$nameの作品${works.length}点です。作品を開くと、背景と見どころを読めます。',
                      style: const TextStyle(color: Palette.textSub, fontSize: 13, height: 1.8),
                    ),
                ],
              ),
            ),
          ),
          if (works.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 36, 24, 14),
                child: SectionHeading(label: 'Works', title: '作品 ${works.length}点'),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 20,
                  crossAxisSpacing: 14,
                  childAspectRatio: 0.68,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, i) => ArtworkThumb(artwork: works[i], knowledge: knowledge),
                  childCount: works.length,
                ),
              ),
            ),
          ] else
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: Text(
                  '作品は著作権の保護期間中のため、画像は載せていません。展覧会や画集で実物に出会ってみてください。',
                  style: TextStyle(color: Palette.textSub, fontSize: 12, height: 1.8),
                ),
              ),
            ),
          SliverToBoxAdapter(child: ExhibitionsSection(keys: keys, title: '$callNameに会える展覧会')),
          SliverToBoxAdapter(
            child: ArtistRow(
              label: 'Contemporaries',
              title: '同じ時代の画家',
              names: knowledge.contemporaries(name),
              knowledge: knowledge,
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 36, 24, 48),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AskCuratorButton(question: '$nameについて、生涯と代表作、ほかの画家への影響をもっと教えてください。'),
                  BookLink(query: '$callName 画集', label: '$callNameの画集を探す'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MovementChip extends StatelessWidget {
  const _MovementChip({required this.movement, required this.knowledge});

  final Movement movement;
  final ArtKnowledge knowledge;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => MovementScreen(movement: movement, knowledge: knowledge)),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          border: Border.all(color: Palette.line),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(movement.nameJa, style: const TextStyle(color: Palette.text, fontSize: 12)),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_forward, size: 13, color: Palette.gold),
          ],
        ),
      ),
    );
  }
}
