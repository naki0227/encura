class TrendingArticle {
  final String id;
  final String title;
  final String summary;
  final String imageUrl;
  final String? sourceUrl;
  final DateTime publishedAt;

  final String? keyword;
  final String? content;

  TrendingArticle({
    required this.id,
    required this.title,
    required this.summary,
    required this.imageUrl,
    this.sourceUrl,
    required this.publishedAt,
    this.keyword,
    this.content,
  });

  factory TrendingArticle.fromJson(Map<String, dynamic> json) {
    return TrendingArticle(
      id: json['id'],
      title: json['title'],
      summary: json['summary'] ?? '',
      imageUrl: json['image_url'] ?? '',
      sourceUrl: json['source_url'],
      publishedAt: json['published_at'] != null 
          ? DateTime.parse(json['published_at']) 
          : DateTime.now(),
      keyword: json['keyword'],
      content: json['content'],
    );
  }
}
