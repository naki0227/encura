import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:encura/core/models/daily_column.dart';
import 'package:encura/core/models/trending_article.dart';
import 'package:encura/core/repositories/daily_column_repository.dart';
import 'package:encura/core/repositories/trending_repository.dart';
import 'package:encura/ui/widgets/daily_art_detail_dialog.dart';

class ArchiveScreen extends StatefulWidget {
  final int initialIndex;

  const ArchiveScreen({super.key, this.initialIndex = 0});

  @override
  State<ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends State<ArchiveScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  
  final DailyColumnRepository _dailyRepository = DailyColumnRepository();
  final TrendingRepository _trendingRepository = TrendingRepository();

  // Daily Art State
  List<DailyColumn> _dailyColumns = [];
  bool _isLoadingDaily = false;
  bool _hasMoreDaily = true;
  int _dailyOffset = 0;

  // Trending State
  List<TrendingArticle> _trendingArticles = [];
  bool _isLoadingTrending = false;
  bool _hasMoreTrending = true;
  int _trendingOffset = 0;

  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialIndex);
    _loadDailyColumns();
    _loadTrendingArticles();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDailyColumns({bool refresh = false}) async {
    if (_isLoadingDaily) return;
    if (refresh) {
      _dailyOffset = 0;
      _hasMoreDaily = true;
      _dailyColumns.clear();
    }
    if (!_hasMoreDaily) return;

    setState(() => _isLoadingDaily = true);

    final newItems = await _dailyRepository.searchColumns(
      query: _searchQuery,
      offset: _dailyOffset,
      limit: 20,
    );

    if (mounted) {
      setState(() {
        _dailyColumns.addAll(newItems);
        _dailyOffset += newItems.length;
        _hasMoreDaily = newItems.length >= 20;
        _isLoadingDaily = false;
      });
    }
  }

  Future<void> _loadTrendingArticles({bool refresh = false}) async {
    if (_isLoadingTrending) return;
    if (refresh) {
      _trendingOffset = 0;
      _hasMoreTrending = true;
      _trendingArticles.clear();
    }
    if (!_hasMoreTrending) return;

    setState(() => _isLoadingTrending = true);

    final newItems = await _trendingRepository.searchArticles(
      query: _searchQuery,
      offset: _trendingOffset,
      limit: 20,
    );

    if (mounted) {
      setState(() {
        _trendingArticles.addAll(newItems);
        _trendingOffset += newItems.length;
        _hasMoreTrending = newItems.length >= 20;
        _isLoadingTrending = false;
      });
    }
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value;
    });
    // Debounce could be added here, but for now just reload on submit or simple delay
    // Let's reload immediately for simplicity or use onSubmitted
  }

  void _onSearchSubmitted(String value) {
    _loadDailyColumns(refresh: true);
    _loadTrendingArticles(refresh: true);
  }

  String _sanitizeUrl(String url) {
    String cleanUrl = url.trim();
    if (cleanUrl.contains(RegExp(r'[^\x00-\x7F]'))) {
      cleanUrl = Uri.encodeFull(cleanUrl);
    }
    return cleanUrl;
  }

  void _showColumnDetails(DailyColumn column) {
    showDialog(
      context: context,
      builder: (context) => DailyArtDetailDialog(column: column),
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
                Image.network(
                  _sanitizeUrl(article.imageUrl),
                  errorBuilder: (context, error, stackTrace) => const SizedBox(),
                ),
              const SizedBox(height: 16),
              Text(article.content ?? article.summary),
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
        title: const Text('Archive'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Daily Art'),
            Tab(text: 'Trending Topics'),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onChanged: _onSearchChanged,
              onSubmitted: _onSearchSubmitted,
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildDailyList(),
                _buildTrendingList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyList() {
    return NotificationListener<ScrollNotification>(
      onNotification: (scrollInfo) {
        if (!_isLoadingDaily &&
            _hasMoreDaily &&
            scrollInfo.metrics.pixels == scrollInfo.metrics.maxScrollExtent) {
          _loadDailyColumns();
        }
        return false;
      },
      child: RefreshIndicator(
        onRefresh: () => _loadDailyColumns(refresh: true),
        child: ListView.builder(
          itemCount: _dailyColumns.length + (_hasMoreDaily ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == _dailyColumns.length) {
              return const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()));
            }
            final column = _dailyColumns[index];
            return ListTile(
              leading: column.imageUrl.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: CachedNetworkImage(
                        imageUrl: _sanitizeUrl(column.imageUrl),
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(width: 50, height: 50, color: Colors.grey),
                        errorWidget: (context, url, error) => Container(width: 50, height: 50, color: Colors.grey),
                      ),
                    )
                  : Container(width: 50, height: 50, color: Colors.grey),
              title: Text(column.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(column.artistName, maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: Text("${column.displayDate.year}-${column.displayDate.month}-${column.displayDate.day}", style: Theme.of(context).textTheme.bodySmall),
              onTap: () => _showColumnDetails(column),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTrendingList() {
    return NotificationListener<ScrollNotification>(
      onNotification: (scrollInfo) {
        if (!_isLoadingTrending &&
            _hasMoreTrending &&
            scrollInfo.metrics.pixels == scrollInfo.metrics.maxScrollExtent) {
          _loadTrendingArticles();
        }
        return false;
      },
      child: RefreshIndicator(
        onRefresh: () => _loadTrendingArticles(refresh: true),
        child: ListView.builder(
          itemCount: _trendingArticles.length + (_hasMoreTrending ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == _trendingArticles.length) {
              return const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()));
            }
            final article = _trendingArticles[index];
            return ListTile(
              leading: article.imageUrl.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: CachedNetworkImage(
                        imageUrl: _sanitizeUrl(article.imageUrl),
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(width: 50, height: 50, color: Colors.grey),
                        errorWidget: (context, url, error) => Container(width: 50, height: 50, color: Colors.grey),
                      ),
                    )
                  : Container(width: 50, height: 50, color: Colors.grey),
              title: Text(article.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(article.summary, maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () => _showArticleDetails(article),
            );
          },
        ),
      ),
    );
  }
}
