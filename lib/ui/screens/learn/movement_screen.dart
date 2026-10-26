import 'package:flutter/material.dart';

import '../../../core/models/art_knowledge.dart';
import '../../theme/tokens.dart';
import '../../widgets/motion.dart';
import 'learn_widgets.dart';

/// One movement: why it began, what changed, what to look for, and the
/// movements it came from and led to.
class MovementScreen extends StatelessWidget {
  const MovementScreen({super.key, required this.movement, required this.knowledge});

  final Movement movement;
  final ArtKnowledge knowledge;

  @override
  Widget build(BuildContext context) {
    final cover = knowledge.coverOf(movement.slug);
    final into = knowledge.linksInto(movement.slug);
    final outOf = knowledge.linksOutOf(movement.slug);
    final works = knowledge.worksOf(movement.slug);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: cover.isEmpty ? null : 300,
            backgroundColor: Palette.room,
            title: Text(movement.nameJa),
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
                      PhotoTag(movement.regionLabel),
                      const SizedBox(width: 12),
                      Text(movement.period,
                          style: const TextStyle(color: Palette.textSub, fontSize: 12, letterSpacing: 1)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    movement.nameJa,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: Palette.text,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                        ),
                  ),
                  Text(movement.nameEn.toUpperCase(),
                      style: const TextStyle(
                          fontFamily: 'Helvetica', color: Palette.gold, fontSize: 11, letterSpacing: 2.4)),
                  const SizedBox(height: 16),
                  Text(movement.summary,
                      style: const TextStyle(color: Palette.text, fontSize: 15, height: 1.8, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 20),
                  const Divider(height: 1, color: Palette.line),
                  const SizedBox(height: 20),
                  ReadingText(movement.body),
                  SourceLink(movement.sourceUrl),
                ],
              ),
            ),
          ),
          if (into.isNotEmpty || outOf.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 36, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionHeading(label: 'Connections', title: 'つながり'),
                    const SizedBox(height: 14),
                    for (final link in into)
                      _LinkCard(link: link, other: knowledge.movement(link.fromSlug), incoming: true, knowledge: knowledge),
                    for (final link in outOf)
                      _LinkCard(link: link, other: knowledge.movement(link.toSlug), incoming: false, knowledge: knowledge),
                  ],
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: ArtworkRow(label: 'Works', title: '代表作', works: works, knowledge: knowledge),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 36, 24, 48),
              child: AskCuratorButton(
                question: '${movement.nameJa}について、代表的な作品を例にして、前後の時代とのつながりも含めてもっと教えてください。',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkCard extends StatelessWidget {
  const _LinkCard({required this.link, required this.other, required this.incoming, required this.knowledge});

  final MovementLink link;
  final Movement? other;
  final bool incoming;
  final ArtKnowledge knowledge;

  @override
  Widget build(BuildContext context) {
    final target = other;
    if (target == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Pressable(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => MovementScreen(movement: target, knowledge: knowledge)),
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Palette.frame,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Palette.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(incoming ? Icons.arrow_back : Icons.arrow_forward, size: 14, color: Palette.gold),
                  const SizedBox(width: 6),
                  Text(
                    incoming ? '${target.nameJa}から' : '${target.nameJa}へ',
                    style: const TextStyle(color: Palette.text, fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  Text(link.kindLabel,
                      style: const TextStyle(color: Palette.gold, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
                ],
              ),
              const SizedBox(height: 8),
              Text(link.note, style: const TextStyle(color: Palette.textSub, fontSize: 13, height: 1.8)),
            ],
          ),
        ),
      ),
    );
  }
}
