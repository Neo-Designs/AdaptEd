import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart'; // REQUIRED FOR SAVING
import '../../features/screening/scoring_engine.dart';
import '../utils/logger.dart';

enum PaletteType { muted, vibrant }

class DynamicTheme extends ChangeNotifier {
  UserTraits _traits = UserTraits.standard();
  PaletteType? _manualPalette;

  // We use nullable booleans so we know if the user manually changed them.
  // If null, we default to their Traits.
  bool? _manualDyslexicFont;
  bool? _manualFocusMode;

  UserTraits get traits => _traits;

  // FIXED LOGIC: If they manually toggled it, use that. Otherwise, use their traits.
  bool get useDyslexicFont => _manualDyslexicFont ?? _traits.isDyslexic;

  // Focus mode defaults to false unless they saved it as true
  bool get focusMode => _manualFocusMode ?? false;

  DynamicTheme() {
    _loadSavedPreferences();
  }

  // --- PERSISTENCE: Load saved settings ---
  Future<void> _loadSavedPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey('useDyslexicFont')) {
      _manualDyslexicFont = prefs.getBool('useDyslexicFont');
    }
    if (prefs.containsKey('focusMode')) {
      _manualFocusMode = prefs.getBool('focusMode');
    }
    notifyListeners();
  }

  PaletteType get currentPalette {
    if (_manualPalette != null) return _manualPalette!;
    return (_traits.isAutistic || _traits.isDyslexic) ? PaletteType.muted : PaletteType.vibrant;
  }

  void setTraits(UserTraits newTraits) {
    if (_traits == newTraits) return;
    _traits = newTraits;
    AppLogger.info('Theme traits updated: ${newTraits.learningProfileName}', tag: 'DynamicTheme');
    notifyListeners();
  }

  // --- PERSISTENCE: Save settings when toggled ---
  Future<void> toggleDyslexicFont() async {
    _manualDyslexicFont = !useDyslexicFont; // Toggle the current active state
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('useDyslexicFont', _manualDyslexicFont!);
  }

  Future<void> toggleFocusMode() async {
    _manualFocusMode = !focusMode;
    AppLogger.info('Focus Mode: $_manualFocusMode', tag: 'DynamicTheme');
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('focusMode', _manualFocusMode!);
  }

  void setManualPalette(PaletteType? type) {
    _manualPalette = type;
    notifyListeners();
  }

  // --- Typography ---
  TextStyle get bodyStyle {
    if (useDyslexicFont) {
      return GoogleFonts.lexend(fontSize: 18, letterSpacing: 0.5, fontWeight: FontWeight.w400);
    }
    return GoogleFonts.lexend(fontSize: 16);
  }

  TextStyle get titleStyle {
    if (useDyslexicFont) {
      return GoogleFonts.lexend(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: 0.8);
    }
    return GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w600);
  }

  TextStyle get buttonTextStyle {
    return GoogleFonts.lexend(fontSize: 16, fontWeight: FontWeight.w600);
  }

  // --- Layout & Spacing ---
  double get buttonMinSize => _traits.isDyspraxic ? 60.0 : 48.0;
  double get interactivePadding => _traits.isDyspraxic ? 24.0 : 12.0;

  // --- Colors ---
  Color get primaryColor {
    if (focusMode) return const Color(0xFF2D3748); // Industrial Slate for focus
    if (currentPalette == PaletteType.muted) return const Color(0xFF6B8E6B);
    if (_traits.isADHD) return const Color(0xFFFF6B6B);
    return const Color(0xFF6366F1); // Default Indigo/Purple-ish
  }

  Color get secondaryColor => const Color(0xFFFFC107); // Amber
  Color get accentColor => const Color(0xFF9C27B0); // Purple Accent
  Color get scaffoldBackgroundColor => backgroundColor;

  Color get backgroundColor {
    if (focusMode) return const Color(0xFFF7FAFC);
    if (currentPalette == PaletteType.muted) return const Color(0xFFFBFBF9);
    return const Color(0xFFF8FAFC);
  }

  Color get cardColor => Colors.white;

  // --- Decoration Tokens ---
  BoxDecoration get glassDecoration => BoxDecoration(
    color: Colors.white.withOpacity(focusMode ? 1.0 : 0.7),
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: primaryColor.withOpacity(0.1)),
    boxShadow: focusMode ? [] : [
      BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
    ],
  );

  bool get showProgressMarkers => _traits.isADHD;
  bool get enableTTS => _traits.isDyslexic;

  Color getAdaptivePaletteColor(int index) {
    final colors = [
      primaryColor,
      secondaryColor,
      Colors.teal,
      Colors.orange
    ];
    return colors[index % colors.length];
  }

  ThemeData get themeData {
    return ThemeData(
      primaryColor: primaryColor,
      scaffoldBackgroundColor: backgroundColor,
      cardColor: cardColor,
      useMaterial3: true,
      textTheme: TextTheme(
        bodyMedium: bodyStyle,
        titleLarge: titleStyle,
        labelLarge: buttonTextStyle,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: backgroundColor,
        titleTextStyle: titleStyle,
        elevation: 0,
        iconTheme: IconThemeData(color: focusMode ? Colors.black87 : Colors.black),
      ),
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        primary: primaryColor,
        secondary: secondaryColor,
        surface: cardColor,
        // background is deprecated in newer Flutter versions, surface is preferred
        background: backgroundColor,
      ),
    );
  }
}