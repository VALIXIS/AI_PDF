import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:pdf_ai_toolkit/models/history_entry.dart';
import 'package:pdf_ai_toolkit/views/home/home_screen.dart';
import 'package:pdf_ai_toolkit/views/history/history_screen.dart';
import 'package:pdf_ai_toolkit/views/settings/settings_screen.dart';
import 'package:pdf_ai_toolkit/services/file_service.dart';

class ThemeNotifier extends ChangeNotifier {
  ThemeMode _mode = ThemeMode.light;
  ThemeMode get mode => _mode;
  bool get isDark => _mode == ThemeMode.dark;
  void toggle() {
    _mode = isDark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
  }
}

final themeNotifier = ThemeNotifier();

// ── Brand colours ─────────────────────────────────────────────────────────
const Color kPrimary = Color(0xFFE03131); // rich red – PDF brand
const Color kPrimaryDark = Color(0xFFFF4D4D); // brighter in dark mode
const Color kBgLight = Color(0xFFF8FAFC);
const Color kCardLight = Colors.white;
const Color kTextLight = Color(0xFF0F172A);
const Color kBgDark = Color(0xFF0A0A10);
const Color kCardDark = Color(0xFF13131F);
const Color kTextDark = Color(0xFFF8FAFC);

// ── Light theme ───────────────────────────────────────────────────────────
ThemeData get lightTheme => ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: kBgLight,
      colorScheme: ColorScheme(
        brightness: Brightness.light,
        primary: kPrimary,
        onPrimary: Colors.white,
        secondary: const Color(0xFF0EA5E9),
        onSecondary: Colors.white,
        error: const Color(0xFFDC2626),
        onError: Colors.white,
        surface: kCardLight,
        onSurface: kTextLight,
      ),
      cardColor: kCardLight,
      appBarTheme: const AppBarTheme(
        backgroundColor: kBgLight,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        foregroundColor: kTextLight,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: TextStyle(
          color: kTextLight,
          fontSize: 17,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge:
            TextStyle(color: kTextLight, fontWeight: FontWeight.w800),
        headlineMedium:
            TextStyle(color: kTextLight, fontWeight: FontWeight.w700),
        headlineSmall:
            TextStyle(color: kTextLight, fontWeight: FontWeight.w700),
        titleLarge: TextStyle(color: kTextLight, fontWeight: FontWeight.w700),
        titleMedium: TextStyle(color: kTextLight, fontWeight: FontWeight.w600),
        titleSmall: TextStyle(color: kTextLight, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(color: kTextLight),
        bodyMedium: TextStyle(color: kTextLight),
        bodySmall: TextStyle(color: Color(0xFF6B7280)),
        labelSmall: TextStyle(color: Color(0xFF6B7280)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: kPrimary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFEEEEF4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kPrimary, width: 1.8),
        ),
        hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );

// ── Dark theme ────────────────────────────────────────────────────────────
ThemeData get darkTheme => ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: kBgDark,
      colorScheme: ColorScheme(
        brightness: Brightness.dark,
        primary: kPrimaryDark,
        onPrimary: Colors.white,
        secondary: const Color(0xFF38BDF8),
        onSecondary: Colors.white,
        error: const Color(0xFFF87171),
        onError: Colors.white,
        surface: kCardDark,
        onSurface: kTextDark,
      ),
      cardColor: kCardDark,
      appBarTheme: const AppBarTheme(
        backgroundColor: kBgDark,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        foregroundColor: kTextDark,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: TextStyle(
          color: kTextDark,
          fontSize: 17,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(color: kTextDark, fontWeight: FontWeight.w800),
        headlineMedium:
            TextStyle(color: kTextDark, fontWeight: FontWeight.w700),
        headlineSmall: TextStyle(color: kTextDark, fontWeight: FontWeight.w700),
        titleLarge: TextStyle(color: kTextDark, fontWeight: FontWeight.w700),
        titleMedium: TextStyle(color: kTextDark, fontWeight: FontWeight.w600),
        titleSmall: TextStyle(color: kTextDark, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(color: kTextDark),
        bodyMedium: TextStyle(color: kTextDark),
        bodySmall: TextStyle(color: Color(0xFF9CA3AF)),
        labelSmall: TextStyle(color: Color(0xFF6B7280)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: kPrimaryDark,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1C1C28),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kPrimaryDark, width: 1.8),
        ),
        hintStyle: const TextStyle(color: Color(0xFF4B5563)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );

// ── Entry point ───────────────────────────────────────────────────────────
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {}
  await Hive.initFlutter();
  Hive.registerAdapter(HistoryEntryAdapter());
  await Hive.openBox<HistoryEntry>('historyBox');

  // Asynchronous background cleanup of orphaned temporary working files
  FileService().cleanOrphanedTempFiles();

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
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI PDF Maker',
      debugShowCheckedModeBanner: false,
      themeMode: themeNotifier.mode,
      theme: lightTheme,
      darkTheme: darkTheme,
      home: const HomeScreen(),
      routes: {
        '/history': (_) => const HistoryScreen(),
        '/settings': (_) => const SettingsScreen(),
      },
    );
  }
}
