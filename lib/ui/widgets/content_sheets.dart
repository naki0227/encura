import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/daily_column.dart';
import '../../core/models/trending_article.dart';
import '../theme/tokens.dart';
import 'reading_sheet.dart';

String _date(DateTime d) {
  final l = d.toLocal();
  return '${l.year}年${l.month}月${l.day}日';
}

/// Today's Art (or an archived one) in the reading view.
Future<void> showDailyArt(BuildContext context, DailyColumn column) {
  return showReadingSheet(
    context,
    imageUrl: column.imageUrl,
    tag: '今日の一枚',
    meta: _date(column.displayDate),
    title: column.title,
    subtitle: column.artistName,
    body: column.content,
    actions: [
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => _openShop(context, column),
          icon: const Icon(Icons.menu_book, size: 18),
          label: const Text('この画家の関連書籍・グッズを探す'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Palette.gold,
            side: const BorderSide(color: Palette.gold),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
        ),
      ),
    ],
  );
}

/// An art news item in the reading view.
Future<void> showNewsArticle(BuildContext context, TrendingArticle article) {
  return showReadingSheet(
    context,
    imageUrl: article.imageUrl,
    tag: article.keyword ?? 'ニュース',
    meta: _date(article.publishedAt),
    title: article.title,
    body: article.content ?? article.summary,
    sourceUrl: article.sourceUrl,
  );
}

Future<void> _openShop(BuildContext context, DailyColumn column) async {
  var url = column.affiliateUrl ?? '';
  if (url.isEmpty) {
    // Fallback to Amazon search
    url = 'https://www.amazon.co.jp/s?k=${Uri.encodeComponent(column.artistName)}';
  }
  var opened = false;
  try {
    opened = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (_) {}
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ページを開けませんでした')));
  }
}
