import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:pdf_ai_toolkit/models/history_entry.dart';
import 'package:pdf_ai_toolkit/views/home/home_screen.dart';
import 'package:pdf_ai_toolkit/views/history/history_screen.dart';

// ---------------------------------------------------------------------------
// Theme notifier – drives the light/dark toggle from the AppBar switch.
// ---------------------------------------------------------------------------
class ThemeNotifier extends ChangeNotifier {
  ThemeMode _mode = ThemeMode.light;

  ThemeMode get mode => _mode;
  bool get isDark => _mode == ThemeMode.dark;

  void toggle() {
    _mode = isDark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
  }
}

// Global notifier so any widget can read / toggle the theme.
final themeNotifier = ThemeNotifier();

// ---------------------------------------------------------------------------
// Colour constants
// ---------------------------------------------------------------------------
const Color kPrimary = Color(0xFF2563EB);
const Color kPrimaryLight = Color(0xFF3B82F6);
const Color kBgLight = Color(0xFFF8FAFC);
const Color kCardLight = Colors.white;
const Color kTextLight = Color(0xFF0F172A);
const Color kBgDark = Color(0xFF0D1117);
const Color kCardDark = Color(0xFF161B22);
const Color kTextDark = Colors.white;

// ---------------------------------------------------------------------------
// Theme definitions
// ---------------------------------------------------------------------------
ThemeData get _lightTheme => ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: kBgLight,
      colorScheme: ColorScheme.fromSeed(
        seedColor: kPrimary,
        brightness: Brightness.light,
        surface: kBgLight,
      ),
      cardColor: kCardLight,
      appBarTheme: const AppBarTheme(
        backgroundColor: kBgLight,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: kTextLight,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(color: kTextLight),
        displayMedium: TextStyle(color: kTextLight),
        displaySmall: TextStyle(color: kTextLight),
        headlineLarge: TextStyle(color: kTextLight),
        headlineMedium: TextStyle(color: kTextLight),
        headlineSmall: TextStyle(color: kTextLight),
        titleLarge: TextStyle(color: kTextLight),
        titleMedium: TextStyle(color: kTextLight),
        titleSmall: TextStyle(color: kTextLight),
        bodyLarge: TextStyle(color: kTextLight),
        bodyMedium: TextStyle(color: kTextLight),
        bodySmall: TextStyle(color: Color(0xFF475569)),
        labelLarge: TextStyle(color: kTextLight),
        labelMedium: TextStyle(color: kTextLight),
        labelSmall: TextStyle(color: kTextLight),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF1F5F9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: kPrimary, width: 1.8),
        ),
        hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
      ),
    );

ThemeData get _darkTheme => ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: kBgDark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: kPrimary,
        brightness: Brightness.dark,
        surface: kBgDark,
      ),
      cardColor: kCardDark,
      appBarTheme: const AppBarTheme(
        backgroundColor: kBgDark,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: kTextDark,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(color: kTextDark),
        displayMedium: TextStyle(color: kTextDark),
        displaySmall: TextStyle(color: kTextDark),
        headlineLarge: TextStyle(color: kTextDark),
        headlineMedium: TextStyle(color: kTextDark),
        headlineSmall: TextStyle(color: kTextDark),
        titleLarge: TextStyle(color: kTextDark),
        titleMedium: TextStyle(color: kTextDark),
        titleSmall: TextStyle(color: kTextDark),
        bodyLarge: TextStyle(color: kTextDark),
        bodyMedium: TextStyle(color: kTextDark),
        bodySmall: TextStyle(color: Color(0xFF94A3B8)),
        labelLarge: TextStyle(color: kTextDark),
        labelMedium: TextStyle(color: kTextDark),
        labelSmall: TextStyle(color: kTextDark),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1E2A36),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF30363D)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF30363D)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: kPrimaryLight, width: 1.8),
        ),
        hintStyle: const TextStyle(color: Color(0xFF4B5563)),
      ),
    );

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {}

  await Hive.initFlutter();
  Hive.registerAdapter(HistoryEntryAdapter());
  await Hive.openBox<HistoryEntry>('historyBox');

  runApp(const PdfAiToolkitApp());
}

class PdfAiToolkitApp extends StatefulWidget {
  const PdfAiToolkitApp({Key? key}) : super(key: key);

  @override
  State<PdfAiToolkitApp> createState() => _PdfAiToolkitAppState();
}

class _PdfAiToolkitAppState extends State<PdfAiToolkitApp> {
  @override
  void initState() {
    super.initState();
    themeNotifier.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    themeNotifier.removeListener(() => setState(() {}));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PDF AI Toolkit',
      debugShowCheckedModeBanner: false,
      themeMode: themeNotifier.mode,
      theme: _lightTheme,
      darkTheme: _darkTheme,
      home: const AppShell(),
      routes: {
        '/history': (_) => const HistoryScreen(),
      },
    );
  }
}
