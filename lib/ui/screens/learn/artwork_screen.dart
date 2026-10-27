import 'package:flutter/material.dart';

import '../../../core/models/art_knowledge.dart';
import '../../../core/services/favorites_store.dart';
import '../../../core/utils/exhibition_match.dart';
import '../../theme/tokens.dart';
import '../../widgets/motion.dart';
import 'learn_widgets.dart';
import 'movement_screen.dart';

/// One artwork: the picture, its story, and where it sits in the flow of art.
class ArtworkScreen extends StatelessWidget {
  const ArtworkScreen({super.key, required this.artwork, required this.knowledge});

  final Artwork artwork;
  final ArtKnowledge knowledge;

  void _zoom(BuildContext context) {
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        transitionDuration: Motion.reduced(context) ? Duration.zero : Motion.mid,
        pageBuilder: (context, _, __) => GestureDetector(
          onTap: () => Navigator.pop(context),
          child: InteractiveViewer(
            maxScale: 5,
            child: Center(child: KnowledgeImage(artwork.imageUrl, fit: BoxFit.contain)),
          ),
        ),
        transitionsBuilder: (context, animation, _, child) =>
            FadeTransition(opacity: CurvedAnimation(parent: animation, curve: Motion.curve), child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final movement = knowledge.movement(artwork.movementSlug);
    final sameArtist = knowledge.byArtist(artwork.artist, except: artwork.id);
    final sameMovement = movement == null
        ? <Artwork>[]
        : knowledge.worksOf(movement.slug).where((a) => a.id != artwork.id && a.artist != artwork.artist).toList();
    final profile = knowledge.artist(artwork.artist);
    final callName = profile?.shortName ?? artwork.artist;

    return Scaffold(
      appBar: AppBar(
        title: Text(movement?.nameJa ?? '作品'),
        actions: [FavoriteButton(artworkId: artwork.id)],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 48),
        children: [
          GestureDetector(
            onTap: () => _zoom(context),
            child: Container(
              color: Palette.room,
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.55),
              width: double.infinity,
              child: KnowledgeImage(artwork.imageUrl, fit: BoxFit.contain),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 8, right: 16),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text('タップで拡大', style: TextStyle(color: Palette.textSub, fontSize: 11)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  artwork.title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Palette.text,
                        fontWeight: FontWeight.w700,
                        height: 1.5,
                      ),
                ),
                const SizedBox(height: 8),
                Pressable(
                  onTap: () => openArtist(context, artwork.artist, knowledge),
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          [artwork.artist, if (artwork.year != null) artwork.yearLabel].join('・'),
                          style: const TextStyle(color: Palette.text, fontSize: 14, letterSpacing: 1),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text('画家のページ', style: TextStyle(color: Palette.gold, fontSize: 11)),
                      const Icon(Icons.chevron_right, size: 16, color: Palette.gold),
                    ],
                  ),
                ),
                if ((artwork.collection ?? '').isNotEmpty) ...[
                  const SizedBox(height: 8),
                  CollectionLink(artwork.collection!),
                ],
                if (movement != null) ...[
                  const SizedBox(height: 16),
                  Pressable(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => MovementScreen(movement: movement, knowledge: knowledge)),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Palette.line),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('${movement.nameJa}・${movement.period}',
                              style: const TextStyle(color: Palette.text, fontSize: 12)),
                          const SizedBox(width: 6),
                          const Icon(Icons.arrow_forward, size: 14, color: Palette.gold),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                const Divider(height: 1, color: Palette.line),
                const SizedBox(height: 20),
                ReadingText(artwork.content),
                AskCuratorButton(question: '${artwork.artist}の「${artwork.title}」について、見どころと時代背景をもっと教えてください。'),
                BookLink(query: '$callName 画集', label: '$callNameの画集を探す'),
              ],
            ),
          ),
          ExhibitionsSection(
            keys: [if (artwork.title.length >= 3) artwork.title, ...artistKeys(artwork.artist, profile)],
            title: 'この作品・画家に会える展覧会',
          ),
          ArtworkRow(label: 'Same artist', title: '${artwork.artist}の作品', works: sameArtist, knowledge: knowledge),
          if (movement != null)
            ArtworkRow(label: 'Same movement', title: '${movement.nameJa}の作品', works: sameMovement, knowledge: knowledge),
        ],
      ),
    );
  }
}

/// ♡ for an artwork. Saved on the device only.
class FavoriteButton extends StatelessWidget {
  const FavoriteButton({super.key, required this.artworkId});

  final String artworkId;

  @override
  Widget build(BuildContext context) {
    final store = FavoritesStore.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final on = store.contains(artworkId);
        return IconButton(
          tooltip: on ? 'お気に入りから外す' : 'お気に入りに入れる',
          onPressed: () => store.toggle(artworkId),
          icon: AnimatedSwitcher(
            duration: Motion.reduced(context) ? Duration.zero : Motion.mid,
            switchInCurve: Motion.curve,
            transitionBuilder: (child, animation) => ScaleTransition(
              scale: Tween(begin: 0.6, end: 1.0).animate(animation),
              child: FadeTransition(opacity: animation, child: child),
            ),
            child: Icon(
              on ? Icons.favorite : Icons.favorite_border,
              key: ValueKey(on),
              color: on ? Palette.gold : Palette.text,
            ),
          ),
        );
      },
    );
  }
}
