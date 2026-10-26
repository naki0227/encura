import 'package:flutter/material.dart';

import '../../../core/models/art_knowledge.dart';
import '../../../core/services/favorites_store.dart';
import '../../theme/tokens.dart';
import '../../widgets/motion.dart';
import 'learn_widgets.dart';

/// Every public-domain work in the app, by movement or by search.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key, required this.knowledge, this.initialMovement, this.favoritesOnly = false});

  final ArtKnowledge knowledge;
  final String? initialMovement;
  final bool favoritesOnly;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  late String? _movement = widget.initialMovement;
  late bool _favorites = widget.favoritesOnly;
  String _query = '';
  final Set<Object> _revealed = {};

  @override
  void initState() {
    super.initState();
    // Coming back from an artwork after changing its ♡ updates the list.
    FavoritesStore.instance.addListener(_changed);
  }

  @override
  void dispose() {
    FavoritesStore.instance.removeListener(_changed);
    super.dispose();
  }

  void _changed() => setState(() {});

  List<Artwork> get _works {
    final q = _query.trim().toLowerCase();
    final favorites = FavoritesStore.instance;
    return widget.knowledge.artworks.where((a) {
      if (_favorites && !favorites.contains(a.id)) return false;
      if (_movement != null && a.movementSlug != _movement) return false;
      if (q.isEmpty) return true;
      return a.title.toLowerCase().contains(q) || a.artist.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final k = widget.knowledge;
    final withWorks = k.movements.where((m) => k.artworks.any((a) => a.movementSlug == m.slug)).toList();
    final works = _works;
    return Scaffold(
      appBar: AppBar(title: const Text('作品ライブラリ')),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: TextField(
                onChanged: (v) => setState(() => _query = v),
                style: const TextStyle(color: Palette.text),
                decoration: InputDecoration(
                  hintText: '作品名・作者名で探す',
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
                  _Chip(
                    label: 'すべて',
                    selected: _movement == null && !_favorites,
                    onTap: () => setState(() {
                      _movement = null;
                      _favorites = false;
                    }),
                  ),
                  _Chip(
                    label: '♡ お気に入り',
                    selected: _favorites,
                    onTap: () => setState(() {
                      _favorites = !_favorites;
                      _movement = null;
                    }),
                  ),
                  for (final m in withWorks)
                    _Chip(
                      label: m.nameJa,
                      selected: _movement == m.slug,
                      onTap: () => setState(() {
                        _movement = m.slug;
                        _favorites = false;
                      }),
                    ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text('${works.length}点', style: const TextStyle(color: Palette.textSub, fontSize: 12)),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 20,
                crossAxisSpacing: 14,
                childAspectRatio: 0.68,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, i) => Reveal(
                  id: works[i].id,
                  seen: _revealed,
                  child: ArtworkThumb(artwork: works[i], knowledge: k),
                ),
                childCount: works.length,
              ),
            ),
          ),
        ],
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
          child: Text(
            label,
            style: TextStyle(color: selected ? Palette.room : Palette.text, fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}
