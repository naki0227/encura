import 'package:flutter/material.dart';
import 'package:encura/core/repositories/event_repository.dart';
import 'package:encura/core/services/event_service.dart';
import 'package:encura/core/repositories/daily_column_repository.dart';
import 'package:encura/core/models/daily_column.dart';
import 'package:encura/core/repositories/trending_repository.dart';
import 'package:encura/core/models/trending_article.dart';

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
        _events = events;
        _dailyColumn = column;
        _trendingArticles = articles;
        _isLoading = false;
      });
    }
  }

  void _showColumnDetails(DailyColumn column) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(column.title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (column.imageUrl.isNotEmpty)
                Image.network(column.imageUrl),
              const SizedBox(height: 8),
              Text('Artist: ${column.artistName}', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Text(column.content),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showArticleDetails(TrendingArticle article) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(article.title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (article.imageUrl.isNotEmpty)
                Image.network(article.imageUrl),
              const SizedBox(height: 16),
              Text(article.content ?? article.summary),
              if (article.sourceUrl != null && article.sourceUrl!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Source: ${article.sourceUrl}', style: const TextStyle(color: Colors.blue)),
              ]
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('EnCura'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                if (_dailyColumn != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Today's Art",
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: () => _showColumnDetails(_dailyColumn!),
                            child: Card(
                              clipBehavior: Clip.antiAlias,
                              elevation: 4,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Stack(
                                    children: [
                                      Image.network(
                                        _dailyColumn!.imageUrl,
                                        height: 200,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) => Container(
                                          height: 200,
                                          color: Colors.grey[300],
                                          child: const Center(child: Icon(Icons.broken_image)),
                                        ),
                                      ),
                                      Positioned(
                                        top: 8,
                                        left: 8,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(alpha: 0.7),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Text(
                                            "Today's Art",
                                            style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _dailyColumn!.title,
                                          style: Theme.of(context).textTheme.titleLarge,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _dailyColumn!.artistName,
                                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_trendingArticles.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Text(
                            "Trending Topics",
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 180,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _trendingArticles.length,
                            itemBuilder: (context, index) {
                              final article = _trendingArticles[index];
                              return GestureDetector(
                                onTap: () => _showArticleDetails(article),
                                child: Container(
                                  width: 160,
                                  margin: const EdgeInsets.only(right: 12),
                                  child: Card(
                                    clipBehavior: Clip.antiAlias,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Stack(
                                          children: [
                                            Image.network(
                                              article.imageUrl,
                                              height: 100,
                                              width: double.infinity,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) => Container(
                                                height: 100,
                                                color: Colors.grey[300],
                                                child: const Center(child: Icon(Icons.broken_image)),
                                              ),
                                            ),
                                            Positioned(
                                              top: 4,
                                              right: 4,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.red,
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    const Icon(Icons.local_fire_department, color: Colors.white, size: 12),
                                                    const SizedBox(width: 2),
                                                    Text(
                                                      article.keyword ?? "Hot",
                                                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Text(
                                            article.title,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      "Nearby Events",
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final event = _events[index];
                      return ListTile(
                        title: Text(event.title),
                        subtitle: Text(event.venue),
                        leading: const Icon(Icons.event),
                        onTap: () {
                          // TODO: Navigate to details
                        },
                      );
                    },
                    childCount: _events.length,
                  ),
                ),
              ],
            ),
    );
  }
}
