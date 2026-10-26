import 'package:flutter/material.dart';

import '../../../core/models/art_knowledge.dart';
import '../../../core/repositories/knowledge_repository.dart';
import '../../../core/services/favorites_store.dart';
import '../../../core/utils/recommend.dart';
import '../../theme/tokens.dart';
import '../../widgets/motion.dart';
import 'artwork_screen.dart';
import 'learn_widgets.dart';
import 'library_screen.dart';
import 'movement_screen.dart';

/// The Learn tab: the flow of art as a timeline, and the library of works.
/// Everything here is written content; the curator is an extra, not a need.
class LearnScreen extends StatefulWidget {
  const LearnScreen({super.key});

  @override
  State<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends State<LearnScreen> {
  final KnowledgeRepository _repository = KnowledgeRepository();
  final Set<Object> _revealed = {};
  ArtKnowledge? _knowledge;
  String? _region;

  @override
  void initState() {
    super.initState();
    FavoritesStore.instance.load();
    _load();
  }

  Future<void> _load() async {
    final knowledge = await _repository.load();
    if (mounted) setState(() => _knowledge = knowledge);
  }

  @override
  Widget build(BuildContext context) {
    final k = _knowledge;
    return Scaffold(
      appBar: AppBar(title: const Text('学ぶ')),
      body: k == null
          ? const Center(child: CircularProgressIndicator(color: Palette.gold, strokeWidth: 2))
          : k.isEmpty
              ? _empty()
              : RefreshIndicator(
                  color: Palette.gold,
                  backgroundColor: Palette.wall,
                  onRefresh: _load,
                  child: _content(k),
                ),
    );
  }

  Widget _empty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('読み込めませんでした。\n通信状況を確かめて、もう一度お試しください。',
                textAlign: TextAlign.center, style: TextStyle(color: Palette.textSub, height: 1.8)),
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: () {
                setState(() => _knowledge = null);
                _load();
              },
              child: const Text('再読み込み'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content(ArtKnowledge k) {
    final movements = _region == null ? k.movements : k.movements.where((m) => m.region == _region).toList();
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: _LibraryEntry(knowledge: k),
          ),
        ),
        SliverToBoxAdapter(
          child: ListenableBuilder(
            listenable: FavoritesStore.instance,
            builder: (context, _) => _ForYou(knowledge: k),
          ),
        ),
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 36, 20, 0),
            child: SectionHeading(label: 'Timeline', title: '美術の流れ'),
          ),
        ),
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 10, 20, 0),
            child: Text(
              '描き方は、前の時代を受け継いだり、反発したり、遠い国から影響を受けたりして移り変わってきました。気になる流れを開くと、そのつながりをたどれます。',
              style: TextStyle(color: Palette.textSub, fontSize: 13, height: 1.9),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 64,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              children: [
                _RegionChip(label: 'すべて', selected: _region == null, onTap: () => setState(() => _region = null)),
                for (final entry in Movement.regionLabels.entries)
                  _RegionChip(
                    label: entry.value,
                    selected: _region == entry.key,
                    onTap: () => setState(() => _region = entry.key),
                  ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 48),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) => Reveal(
                id: movements[i].slug,
                seen: _revealed,
                child: _TimelineItem(
                  movement: movements[i],
                  knowledge: k,
                  last: i == movements.length - 1,
                ),
              ),
              childCount: movements.length,
            ),
          ),
        ),
      ],
    );
  }
}

class _LibraryEntry extends StatelessWidget {
  const _LibraryEntry({required this.knowledge});

  final ArtKnowledge knowledge;

  @override
  Widget build(BuildContext context) {
    // Two works from far apart in time, like two walls of a gallery.
    final covers = [
      if (knowledge.artworks.isNotEmpty) knowledge.artworks.first,
      if (knowledge.artworks.length > 1) knowledge.artworks[knowledge.artworks.length ~/ 2],
    ];
    return Pressable(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LibraryScreen(knowledge: knowledge))),
      child: Container(
        height: 132,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Palette.frame,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Palette.line),
        ),
        child: Row(
          children: [
            for (final a in covers)
              Expanded(child: SizedBox.expand(child: KnowledgeImage(a.imageUrl))),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('LIBRARY',
                        style: TextStyle(fontFamily: 'Helvetica', color: Palette.gold, fontSize: 11, letterSpacing: 2.4)),
                    const SizedBox(height: 6),
                    const Text('作品ライブラリ',
                        style: TextStyle(color: Palette.text, fontSize: 17, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text('${knowledge.artworks.length}点の名画と解説',
                        style: const TextStyle(color: Palette.textSub, fontSize: 12)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RegionChip extends StatelessWidget {
  const _RegionChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Pressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: Motion.reduced(context) ? Duration.zero : Motion.fast,
          curve: Motion.curve,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? Palette.text : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? Palette.text : Palette.line),
          ),
          child: Text(label,
              style: TextStyle(color: selected ? Palette.room : Palette.text, fontSize: 12, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }
}

/// One stop on the timeline: the year on a gold thread, the movement beside it.
class _TimelineItem extends StatelessWidget {
  const _TimelineItem({required this.movement, required this.knowledge, required this.last});

  final Movement movement;
  final ArtKnowledge knowledge;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final cover = knowledge.coverOf(movement.slug);
    final count = knowledge.worksOf(movement.slug).length;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 52,
            child: Column(
              children: [
                const SizedBox(height: 18),
                Text('${movement.startYear}',
                    style: const TextStyle(color: Palette.gold, fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(color: Palette.gold, shape: BoxShape.circle),
                ),
                Expanded(
                  child: Container(width: 1, color: last ? Colors.transparent : const Color(0x66C5A059)),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Pressable(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => MovementScreen(movement: movement, knowledge: knowledge)),
                ),
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: Palette.frame,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Palette.line),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${movement.regionLabel}・${movement.period}',
                                  style: const TextStyle(color: Palette.textSub, fontSize: 11, letterSpacing: 0.5)),
                              const SizedBox(height: 6),
                              Text(movement.nameJa,
                                  style: const TextStyle(color: Palette.text, fontSize: 16, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 6),
                              Text(
                                movement.summary,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Palette.textSub, fontSize: 12, height: 1.7),
                              ),
                              if (count > 0) ...[
                                const SizedBox(height: 8),
                                Text('作品 $count点',
                                    style: const TextStyle(color: Palette.gold, fontSize: 11, fontWeight: FontWeight.w700)),
                              ],
                            ],
                          ),
                        ),
                      ),
                      if (cover.isNotEmpty) SizedBox(width: 84, child: KnowledgeImage(cover)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Suggestions from the works marked with ♡ (worked out on the device), or a
/// hint on how to get them.
class _ForYou extends StatelessWidget {
  const _ForYou({required this.knowledge});

  final ArtKnowledge knowledge;

  @override
  Widget build(BuildContext context) {
    final favorites = FavoritesStore.instance.ids;
    if (favorites.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Palette.line),
          ),
          child: const Row(
            children: [
              Icon(Icons.favorite_border, color: Palette.gold, size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  '気になる作品に♡を付けると、好みに合いそうな作品をここでおすすめします。♡はこの端末の中だけに保存されます。',
                  style: TextStyle(color: Palette.textSub, fontSize: 12, height: 1.8),
                ),
              ),
            ],
          ),
        ),
      );
    }
    final recs = recommend(knowledge, favorites);
    return Padding(
      padding: const EdgeInsets.only(top: 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SectionHeading(
              label: 'For you',
              title: 'あなたへのおすすめ',
              trailing: TextButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => LibraryScreen(knowledge: knowledge, favoritesOnly: true)),
                ),
                icon: const Icon(Icons.favorite, size: 14, color: Palette.gold),
                label: Text('${favorites.length}', style: const TextStyle(color: Palette.text)),
              ),
            ),
          ),
          if (recs.isNotEmpty) ...[
            const SizedBox(height: 14),
            SizedBox(
              height: 262,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: recs.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, i) => _RecommendationCard(recommendation: recs[i], knowledge: knowledge),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({required this.recommendation, required this.knowledge});

  final Recommendation recommendation;
  final ArtKnowledge knowledge;

  @override
  Widget build(BuildContext context) {
    final a = recommendation.artwork;
    return Pressable(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ArtworkScreen(artwork: a, knowledge: knowledge)),
      ),
      child: SizedBox(
        width: 150,
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
                child: KnowledgeImage(a.imageUrl),
              ),
            ),
            const SizedBox(height: 8),
            Text(a.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Palette.text, fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(recommendation.reason,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Palette.gold, fontSize: 11, height: 1.5)),
          ],
        ),
      ),
    );
  }
}
