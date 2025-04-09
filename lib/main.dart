import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:share_plus/share_plus.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  await NotificationService().init();
  runApp(const DailyQuoteApp());
}

class DailyQuoteApp extends StatelessWidget {
  const DailyQuoteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Daily Quote Cards',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.deepPurple),
      home: const QuoteCardScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class QuoteCardScreen extends StatefulWidget {
  const QuoteCardScreen({super.key});

  @override
  State<QuoteCardScreen> createState() => _QuoteCardScreenState();
}

class _QuoteCardScreenState extends State<QuoteCardScreen> {
  final List<String> quotes = [
    "Believe in yourself.",
    "Every day is a second chance.",
    "Start where you are. Use what you have.",
    "Push yourself, because no one else will.",
    "Stay positive, work hard, make it happen.",
    "Don’t stop until you’re proud.",
    "You are stronger than you think.",
    "Small steps every day.",
    "Dream big and dare to fail.",
  ];

  int? currentIndex;
  List<int> favoriteIndices = [];

  @override
  void initState() {
    super.initState();
    _loadDailyQuote();
    _loadFavorites();
    NotificationService().scheduleDailyQuoteNotification(quotes);
  }

  Future<void> _loadDailyQuote() async {
    final prefs = await SharedPreferences.getInstance();
    final savedDate = prefs.getString('quote_date');
    final today = DateTime.now().toIso8601String().split('T')[0];

    if (savedDate != today) {
      final newIndex = Random().nextInt(quotes.length);
      await prefs.setInt('quote_index', newIndex);
      await prefs.setString('quote_date', today);
      setState(() => currentIndex = newIndex);
    } else {
      setState(() => currentIndex = prefs.getInt('quote_index') ?? 0);
    }
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      favoriteIndices =
          prefs.getStringList('favorites')?.map(int.parse).toList() ?? [];
    });
  }

  Future<void> _toggleFavorite() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (favoriteIndices.contains(currentIndex)) {
        favoriteIndices.remove(currentIndex);
      } else {
        favoriteIndices.add(currentIndex!);
      }
    });
    await prefs.setStringList(
      'favorites',
      favoriteIndices.map((e) => e.toString()).toList(),
    );
  }

  void _shareQuote() {
    if (currentIndex != null) {
      Share.share(quotes[currentIndex!], subject: "Today's Quote");
    }
  }

  void _goToFavorites() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => FavoritesScreen(
              favoriteQuotes: favoriteIndices.map((i) => quotes[i]).toList(),
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final quote = currentIndex != null ? quotes[currentIndex!] : "";
    final isFavorite = favoriteIndices.contains(currentIndex);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Quote'),
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite),
            onPressed: _goToFavorites,
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            child: Card(
              key: ValueKey(currentIndex),
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              color: Colors.white,
              child: Container(
                width: double.infinity,
                height: 300,
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      quote,
                      style: const TextStyle(
                        fontSize: 24,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: Icon(
                            isFavorite ? Icons.favorite : Icons.favorite_border,
                            color: Colors.red,
                          ),
                          onPressed: _toggleFavorite,
                        ),
                        IconButton(
                          icon: const Icon(Icons.share),
                          onPressed: _shareQuote,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class FavoritesScreen extends StatelessWidget {
  final List<String> favoriteQuotes;

  const FavoritesScreen({super.key, required this.favoriteQuotes});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Favorites')),
      body: ListView.builder(
        itemCount: favoriteQuotes.length,
        itemBuilder: (context, index) {
          return ListTile(
            leading: const Icon(Icons.format_quote),
            title: Text(favoriteQuotes[index]),
          );
        },
      ),
    );
  }
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
    );
    await _plugin.initialize(initSettings);
  }

  Future<void> scheduleDailyQuoteNotification(List<String> quotes) async {
    final quote = quotes[Random().nextInt(quotes.length)];
    await _plugin.zonedSchedule(
      0,
      'Daily Quote ✨',
      quote,
      _nextInstanceOf9AM(),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_quote_channel',
          'Daily Quotes',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  tz.TZDateTime _nextInstanceOf9AM() {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, 9);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
