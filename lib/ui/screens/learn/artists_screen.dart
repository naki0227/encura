import 'package:flutter/material.dart';

import '../../../core/models/art_knowledge.dart';
import '../../theme/tokens.dart';
import '../../widgets/motion.dart';
import 'learn_widgets.dart';

/// Every artist, in order of when they were active, by region or by search.
class ArtistsScreen extends StatefulWidget {
  const ArtistsScreen({super.key, required this.knowledge});

  final ArtKnowledge knowledge;

  @override
  State<ArtistsScreen> createState() => _ArtistsScreenState();
}

class _ArtistsScreenState extends State<ArtistsScreen> {
  String? _region;
  String _query = '';
  final Set<Object> _revealed = {};

  List<String> get _names {
    final k = widget.knowledge;
    final q = _query.trim().toLowerCase();
    return k.artistNames.where((name) {
      if (_region != null && k.regionOf(name) != _region) return false;
      if (q.isEmpty) return true;
      final profile = k.artist(name);
      return name.toLowerCase().contains(q) ||
          (profile?.nameEn.toLowerCase().contains(q) ?? false) ||
          (profile?.shortName?.contains(q) ?? false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final k = widget.knowledge;
    final names = _names;
    return Scaffold(
      appBar: AppBar(title: const Text('画家')),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: TextField(
                onChanged: (v) => setState(() => _query = v),
                style: const TextStyle(color: Palette.text),
                decoration: InputDecoration(
                  hintText: '画家の名前で探す',
                  hintStyle: const TextStyle(color: Palette.textSub),
                  prefixIcon: const Icon(Icons.search, color: Palette.textSub),
                  filled: true,
                  fillColor: Palette.wall,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  _Chip(label: 'すべて', selected: _region == null, onTap: () => setState(() => _region = null)),
                  for (final e in Movement.regionLabels.entries)
                    _Chip(label: e.value, selected: _region == e.key, onTap: () => setState(() => _region = e.key)),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text('${names.length}人・時代順', style: const TextStyle(color: Palette.textSub, fontSize: 12)),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) => Reveal(
                  id: names[i],
                  seen: _revealed,
                  child: _ArtistTile(name: names[i], knowledge: k),
                ),
                childCount: names.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArtistTile extends StatelessWidget {
  const _ArtistTile({required this.name, required this.knowledge});

  final String name;
  final ArtKnowledge knowledge;

  @override
  Widget build(BuildContext context) {
    final profile = knowledge.artist(name);
    final from = knowledge.activeFrom(name);
    final years = profile != null && profile.lifeLabel.isNotEmpty ? profile.lifeLabel : (from == null ? '' : '$from年ごろ');
    final movements = knowledge.movementsOf(name).map((m) => m.nameJa).join('・');
    final count = knowledge.byArtist(name).length;
    final cover = knowledge.coverOfArtist(name);
    return Pressable(
      onTap: () => openArtist(context, name, knowledge),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Palette.line))),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              clipBehavior: Clip.antiAlias,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: Palette.frame),
              child: cover.isEmpty
                  ? Center(
                      child: Text(name.split(RegExp(r'[・＝=]')).last.characters.first,
                          style: const TextStyle(color: Palette.gold, fontSize: 20, fontWeight: FontWeight.w700)),
                    )
                  : KnowledgeImage(cover),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(color: Palette.text, fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(
                    [if (years.isNotEmpty) years, if (movements.isNotEmpty) movements].join('　'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Palette.textSub, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (count > 0) Text('$count点', style: const TextStyle(color: Palette.gold, fontSize: 12)),
            const Icon(Icons.chevron_right, color: Palette.textSub, size: 20),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap});

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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
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
