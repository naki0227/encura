class DailyColumn {
  final String id;
  final String title;
  final String artistName;
  final String imageUrl;
  final String content;
  final DateTime displayDate;
  final String? affiliateUrl;

  DailyColumn({
    required this.id,
    required this.title,
    required this.artistName,
    required this.imageUrl,
    required this.content,
    required this.displayDate,
    this.affiliateUrl,
  });

  factory DailyColumn.fromJson(Map<String, dynamic> json) {
    return DailyColumn(
      id: json['id'],
      title: json['title'],
      artistName: json['artist'],
      imageUrl: json['image_url'],
      content: json['content'],
      displayDate: DateTime.parse(json['display_date']),
      affiliateUrl: json['affiliate_url'],
    );
  }
}
