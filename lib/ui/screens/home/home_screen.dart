import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:encura/core/repositories/event_repository.dart';
import 'package:encura/core/services/event_service.dart';
import '../event/event_detail_screen.dart';
import 'package:encura/core/repositories/daily_column_repository.dart';
import 'package:encura/core/models/daily_column.dart';
import 'package:encura/core/repositories/trending_repository.dart';
import 'package:encura/core/models/trending_article.dart';
import 'package:encura/ui/screens/venue/venue_search_screen.dart';
import 'package:encura/ui/screens/settings/settings_screen.dart';
import 'package:encura/ui/screens/archive/archive_screen.dart';
import 'package:encura/ui/widgets/content_sheets.dart';
import '../../../core/utils/event_order.dart';
import '../../../core/utils/image_url.dart';
import '../../theme/tokens.dart';
import '../../widgets/motion.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final EventRepository _eventRepository = EventRepository();
  final DailyColumnRepository _dailyColumnRepository = DailyColumnRepository();
  final TrendingRepository _trendingRepository = TrendingRepository();
  
  List<ArtEvent> _events = [];
  /// Where the user is, once location is allowed; the list is then nearest first.
  LatLng? _here;
  /// Cards that already played their entrance, so scrolling back does not replay it.
  final Set<Object> _revealed = {};
  DailyColumn? _dailyColumn;
  List<TrendingArticle> _trendingArticles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final events = await _eventRepository.getEvents();
    final column = await _dailyColumnRepository.getTodayColumn();
    final articles = await _trendingRepository.getTrendingArticles();
    
    if (mounted) {
      setState(() {
        _events = _ordered(events);
        _dailyColumn = column;
        _trendingArticles = articles;
        _isLoading = false;
      });
    }
    // Show the list first; re-sort by distance once the location is known.
    final here = await _currentLocation();
    if (here != null && mounted) {
      setState(() {
        _here = here;
        _events = _ordered(_events);
      });
    }
  }

  List<ArtEvent> _ordered(List<ArtEvent> events) {
    final today = DateTime.now();
    return _here == null ? orderForHome(events, today) : orderByDistance(events, _here!, today);
  }

  /// The current location, or null when it is off, not allowed or slow.
  Future<LatLng?> _currentLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return null;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 10),
        ),
      );
      return LatLng(position.latitude, position.longitude);
    } catch (e) {
      debugPrint('Location unavailable: $e');
      return null;
    }
  }

  void _showColumnDetails(DailyColumn column) => showDailyArt(context, column);

  void _showArticleDetails(TrendingArticle article) => showNewsArticle(context, article);

  String _sanitizeUrl(String url) => normalizeImageUrl(url);

  bool get _hasContent => _dailyColumn != null || _trendingArticles.isNotEmpty || _events.isNotEmpty;

  List<Widget> _actions() => [
        IconButton(
          icon: const Icon(Icons.search, color: Colors.white),
          tooltip: '美術館を探す',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const VenueSearchScreen()),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.history, color: Colors.white),
          tooltip: 'アーカイブ',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ArchiveScreen(initialIndex: 0)),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.settings, color: Colors.white),
          tooltip: '設定',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SettingsScreen()),
          ),
        ),
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('EnCura'),
        // The buttons normally sit on the Today's Art header; without it
        // (offline, or nothing scheduled) they must stay reachable.
        actions: _isLoading || _dailyColumn != null ? null : _actions(),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Palette.gold, strokeWidth: 2))
          : !_hasContent
              ? _buildEmptyState()
              : RefreshIndicator(
                  color: Palette.gold,
                  backgroundColor: Palette.wall,
                  onRefresh: _loadData,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      if (_dailyColumn != null) _buildTodaysArt(context, _dailyColumn!),
                      if (_trendingArticles.isNotEmpty) _buildTopics(context),
                      if (_events.isNotEmpty) ...[
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                            child: SectionHeading(
                              label: _here == null ? 'Exhibitions' : 'Nearby',
                              title: _here == null ? '開催中・まもなく' : '近くの展覧会',
                            ),
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) => _buildEventCard(context, _events[index]),
                              childCount: _events.length,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }

  Widget _buildTodaysArt(BuildContext context, DailyColumn column) {
    final reduced = Motion.reduced(context);
    return SliverAppBar(
      expandedHeight: MediaQuery.of(context).size.height * 0.6,
      pinned: true,
      stretch: true,
      backgroundColor: Palette.room,
      actions: _actions(),
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.zoomBackground],
        background: Stack(
          fit: StackFit.expand,
          children: [
            // The work settles into place once (1.03 → 1), like a light coming up.
            TweenAnimationBuilder<double>(
              tween: Tween(begin: reduced ? 1 : 1.03, end: 1),
              duration: const Duration(milliseconds: 2000),
              curve: Motion.curve,
              builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
              child: CachedNetworkImage(
                imageUrl: _sanitizeUrl(column.imageUrl),
                httpHeaders: imageHeaders,
                fit: BoxFit.cover,
                fadeInDuration: reduced ? Duration.zero : Motion.slow,
                fadeInCurve: Motion.curve,
                placeholder: (context, url) => Container(color: Palette.wall),
                errorWidget: (context, url, error) {
                  debugPrint('Today\'s Art Image load error: $error. URL: $url');
                  return Container(color: Palette.wall);
                },
              ),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x66000000), Colors.transparent, Colors.transparent, Color(0xE6000000)],
                  stops: [0, 0.18, 0.55, 1],
                ),
              ),
            ),
            Positioned(
              bottom: 24,
              left: 20,
              right: 20,
              child: _FadeWhenCollapsed(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const PhotoTag('今日の一枚'),
                    const SizedBox(height: 14),
                    Text(
                      column.title,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            color: Palette.text,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                            height: 1.3,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      column.artistName,
                      style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 14, letterSpacing: 1),
                    ),
                    const SizedBox(height: 18),
                    OutlinedButton.icon(
                      onPressed: () => _showColumnDetails(column),
                      icon: const Icon(Icons.arrow_forward, size: 16),
                      iconAlignment: IconAlignment.end,
                      label: const Text('解説を読む'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Palette.text,
                        side: const BorderSide(color: Color(0x99FFFFFF)),
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        textStyle: const TextStyle(fontSize: 13, letterSpacing: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopics(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 32, 0, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: SectionHeading(label: 'Topics', title: '美術のニュース'),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 262,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _trendingArticles.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final article = _trendingArticles[index];
                  return Reveal(
                    id: 'topic-${article.title}',
                    seen: _revealed,
                    child: Pressable(
                      onTap: () => _showArticleDetails(article),
                      child: SizedBox(
                        width: 168,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Container(
                                clipBehavior: Clip.antiAlias,
                                decoration: BoxDecoration(
                                  color: Palette.frame,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Palette.line),
                                ),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    article.imageUrl.isNotEmpty
                                        ? CachedNetworkImage(
                                            imageUrl: _sanitizeUrl(article.imageUrl),
                                            httpHeaders: imageHeaders,
                                            fit: BoxFit.cover,
                                            fadeInCurve: Motion.curve,
                                            placeholder: (context, url) => Container(color: Palette.frame),
                                            errorWidget: (context, url, error) {
                                              debugPrint('Trending Topic Image load error: $error. URL: $url');
                                              return _noImageCover(context, article.keyword);
                                            },
                                          )
                                        : _noImageCover(context, article.keyword),
                                    // Without a photo the cover already shows the category.
                                    if (article.imageUrl.isNotEmpty)
                                      Positioned(top: 10, left: 10, child: PhotoTag(article.keyword ?? 'ニュース')),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              article.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Palette.text,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                height: 1.5,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventCard(BuildContext context, ArtEvent event) {
    final today = DateTime.now();
    // A running show is worth visiting before it closes; an upcoming one,
    // from its opening day.
    final running = isRunning(event, today);
    final stubDate = running ? event.endDate : event.startDate;
    final km = distanceKm(event, _here);
    final status = _eventStatus(event, today);
    return Reveal(
      id: 'event-${event.id}',
      seen: _revealed,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Pressable(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => EventDetailScreen(event: event)),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Palette.frame,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Palette.line),
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Ticket stub (date)
                  Container(
                    width: 72,
                    decoration: const BoxDecoration(
                      border: Border(right: BorderSide(color: Palette.line)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${stubDate.month}月',
                          style: const TextStyle(color: Palette.textSub, fontSize: 11, letterSpacing: 1),
                        ),
                        Text(
                          '${stubDate.day}',
                          style: const TextStyle(color: Palette.text, fontSize: 28, fontWeight: FontWeight.w300, height: 1.2),
                        ),
                        Text(
                          running ? 'まで' : 'から',
                          style: const TextStyle(color: Palette.textSub, fontSize: 11, letterSpacing: 1),
                        ),
                      ],
                    ),
                  ),
                  // Ticket body (details)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            status.label,
                            style: TextStyle(
                              color: status.urgent ? Palette.gold : Palette.textSub,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            event.title,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Palette.text,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            km == null
                                ? event.venue
                                : '${event.venue}・${km < 10 ? km.toStringAsFixed(1) : km.round()} km',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Palette.textSub, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// What matters about the dates right now, in a few characters.
  ({String label, bool urgent}) _eventStatus(ArtEvent event, DateTime today) {
    final day = DateTime(today.year, today.month, today.day);
    int daysTo(DateTime d) => DateTime(d.year, d.month, d.day).difference(day).inDays;
    if (isRunning(event, today)) {
      final left = daysTo(event.endDate);
      if (left == 0) return (label: '本日まで', urgent: true);
      if (left <= 7) return (label: 'あと$left日で終了', urgent: true);
      return (label: '開催中', urgent: false);
    }
    final until = daysTo(event.startDate);
    if (until <= 7) return (label: 'あと$until日で開幕', urgent: true);
    return (label: 'まもなく開幕', urgent: false);
  }

  /// News without a usable image: the category set large and quiet, like a
  /// placard on an empty wall, instead of a broken-image icon.
  Widget _noImageCover(BuildContext context, String? keyword) {
    return Container(
      color: Palette.frame,
      alignment: Alignment.bottomLeft,
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      child: Text(
        keyword ?? 'ニュース',
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: const Color(0x33FFFFFF),
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: Palette.textSub),
            const SizedBox(height: 16),
            const Text(
              '情報を読み込めませんでした。\n通信状況を確認して、もう一度お試しください。',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () {
                setState(() => _isLoading = true);
                _loadData();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('再読み込み'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fades the Today's Art caption out as the header collapses, so the title is
/// never cut in half by the pinned bar.
class _FadeWhenCollapsed extends StatelessWidget {
  const _FadeWhenCollapsed({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final settings = context.dependOnInheritedWidgetOfExactType<FlexibleSpaceBarSettings>();
    if (settings == null) return child;
    final range = settings.maxExtent - settings.minExtent;
    final open = range <= 0 ? 1.0 : ((settings.currentExtent - settings.minExtent) / range).clamp(0.0, 1.0);
    // Fully visible above 70% open, gone below 40%.
    final opacity = ((open - 0.4) / 0.3).clamp(0.0, 1.0);
    return Opacity(opacity: opacity, child: IgnorePointer(ignoring: opacity == 0, child: child));
  }
}
