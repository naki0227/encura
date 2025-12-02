import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'core/services/supabase_service.dart';
import 'ui/screens/home/home_screen.dart';
import 'ui/screens/chat/chat_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await SupabaseService.initialize();
  await SupabaseService.signInAnonymously();
  runApp(const EnCuraApp());
}

class EnCuraApp extends StatelessWidget {
  const EnCuraApp({super.key});

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFFC5A059);
    const backgroundColor = Color(0xFF121212);
    const surfaceColor = Color(0xFF1E1E1E);

    return MaterialApp(
      title: 'EnCura',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: backgroundColor,
        primaryColor: primaryColor,
        colorScheme: const ColorScheme.dark(
          primary: primaryColor,
          secondary: primaryColor,
          surface: surfaceColor,
          onSurface: Colors.white,
        ),
        useMaterial3: true,
        textTheme: GoogleFonts.shipporiMinchoTextTheme(
          ThemeData.dark().textTheme,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: backgroundColor,
          foregroundColor: primaryColor,
          centerTitle: true,
          elevation: 0,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: backgroundColor,
          selectedItemColor: primaryColor,
          unselectedItemColor: Colors.grey,
        ),
        cardTheme: CardThemeData(
          color: surfaceColor,
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      home: const MainScreen(),
    );
  }
}



class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  
  static const List<Widget> _screens = [
    HomeScreen(),
    ChatScreen(),
    // EventMapScreen(), // Temporarily disabled or moved
  ];

  @override
  void initState() {
    super.initState();
    _checkFirstTime();
  }

  Future<void> _checkFirstTime() async {
    final prefs = await SharedPreferences.getInstance();
    final hasAgreed = prefs.getBool('has_agreed_to_terms') ?? false;

    if (!hasAgreed && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showAgreementDialog(prefs);
      });
    }
  }

  void _showAgreementDialog(SharedPreferences prefs) {
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent closing without agreement
      builder: (context) => AlertDialog(
        title: const Text('AI解説と投稿に関する注意事項'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('本アプリを利用する前に、以下の注意事項に同意してください。'),
              SizedBox(height: 16),
              Text('・本アプリの解説はAIによって生成されており、正確性を保証するものではありません。'),
              SizedBox(height: 12),
              Text('・マップ投稿機能では、ご自身が撮影した画像、または共有の許可を得ている画像のみを投稿してください。'),
              SizedBox(height: 12),
              Text('・違法な画像や不適切なコンテンツは予告なく削除される場合があります。'),
              SizedBox(height: 24),
              Text('利用規約とプライバシーポリシー', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              InkWell(
                child: Text(
                  '利用規約・プライバシーポリシーを確認する',
                  style: TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
                ),
                onTap: () async {
                  final Uri url = Uri.parse('https://garrulous-court-1b7.notion.site/EnCura-2bda7052569880f1a124c2b45d0b4c9b?source=copy_link');
                  if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
                    debugPrint('Could not launch $url');
                  }
                },
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              await prefs.setBool('has_agreed_to_terms', true);
              if (mounted) Navigator.pop(context);
            },
            child: const Text('同意して利用を開始'),
          ),
        ],
      ),
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onItemTapped,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'Curator',
          ),
        ],
      ),
    );
  }
}
