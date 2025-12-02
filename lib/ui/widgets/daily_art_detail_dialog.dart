import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:encura/core/models/daily_column.dart';

class DailyArtDetailDialog extends StatelessWidget {
  final DailyColumn column;

  const DailyArtDetailDialog({super.key, required this.column});

  String _sanitizeUrl(String url) {
    String cleanUrl = url.trim();
    if (cleanUrl.contains(RegExp(r'[^\x00-\x7F]'))) {
      cleanUrl = Uri.encodeFull(cleanUrl);
    }
    return cleanUrl;
  }

  Future<void> _launchAffiliateUrl(BuildContext context) async {
    String url = column.affiliateUrl ?? '';
    if (url.isEmpty) {
      // Fallback to Amazon search
      url = 'https://www.amazon.co.jp/s?k=${Uri.encodeComponent(column.artistName)}';
    }

    final Uri uri = Uri.parse(url);
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not launch $url')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error launching URL: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Gold color for the button
    const goldColor = Color(0xFFC5A059);

    return AlertDialog(
      title: Text(column.title),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (column.imageUrl.isNotEmpty)
              CachedNetworkImage(
                imageUrl: _sanitizeUrl(column.imageUrl),
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(color: Colors.grey[900]),
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey[900],
                  child: const Center(child: Icon(Icons.broken_image, color: Colors.white54)),
                ),
              ),
            const SizedBox(height: 8),
            Text('Artist: ${column.artistName}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Text(column.content),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _launchAffiliateUrl(context),
                icon: const Icon(Icons.menu_book, color: goldColor),
                label: const Text(
                  'この画家の関連書籍・グッズを探す',
                  style: TextStyle(color: goldColor, fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: goldColor),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
