import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _version = packageInfo.version;
      });
    }
  }

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch $url')),
        );
      }
    }
  }

  void _showDisclaimerDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('AI解説と投稿に関する注意事項'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('・本アプリの解説はAIによって生成されており、正確性を保証するものではありません。'),
              SizedBox(height: 12),
              Text('・マップ投稿機能では、ご自身が撮影した画像、または共有の許可を得ている画像のみを投稿してください。'),
              SizedBox(height: 12),
              Text('・違法な画像や不適切なコンテンツは予告なく削除される場合があります。'),
              SizedBox(height: 24),
              Text(
                'EnCuraは学生によって個人開発されています。もし気に入っていただけたら、開発継続のための支援をいただけると励みになります。',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.description),
            title: const Text('利用規約'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _launchUrl('https://garrulous-court-1b7.notion.site/EnCura-2bda7052569880f1a124c2b45d0b4c9b?source=copy_link'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.privacy_tip),
            title: const Text('プライバシーポリシー'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _launchUrl('https://garrulous-court-1b7.notion.site/EnCura-2bda7052569880f1a124c2b45d0b4c9b?source=copy_link'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.mail),
            title: const Text('お問い合わせ'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _launchUrl('mailto:nakinakipal@gmail.com'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.volunteer_activism, color: Colors.pinkAccent),
            title: const Text('開発者を応援する (Ofuse)'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _launchUrl('https://ofuse.me/292a29e6'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.warning),
            title: const Text('AI解説と投稿に関する注意事項'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showDisclaimerDialog,
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('アプリのバージョン'),
            trailing: Text(_version),
          ),
        ],
      ),
    );
  }
}
