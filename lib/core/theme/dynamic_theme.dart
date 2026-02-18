import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../features/screening/scoring_engine.dart';
import '../utils/logger.dart';

enum PaletteType { muted, vibrant }

class DynamicTheme extends ChangeNotifier {
  UserTraits _traits = UserTraits.standard();
  PaletteType? _manualPalette;
  bool _useDyslexicFont = false;
  bool _focusMode = false;
  
  UserTraits get traits => _traits;
  bool get useDyslexicFont => _useDyslexicFont || _traits.isDyslexic;
  bool get focusMode => _focusMode;

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

  void toggleDyslexicFont() {
    _useDyslexicFont = !_useDyslexicFont;
    notifyListeners();
  }

  void toggleFocusMode() {
    _focusMode = !_focusMode;
    AppLogger.info('Focus Mode: $_focusMode', tag: 'DynamicTheme');
    notifyListeners();
  }

  void setManualPalette(PaletteType? type) {
    _manualPalette = type;
    notifyListeners();
  }

  // --- Typography ---
  // Lexend is specifically designed to reduce visual noise and improve reading speed for neurodivergent users.
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
    if (_focusMode) return const Color(0xFF2D3748); // Industrial Slate for focus
    if (currentPalette == PaletteType.muted) return const Color(0xFF6B8E6B);
    if (_traits.isADHD) return const Color(0xFFFF6B6B);
    return const Color(0xFF6366F1); // Default Indigo/Purple-ish
  }

  // Requested Missing Colors
  Color get secondaryColor => const Color(0xFFFFC107); // Amber
  Color get accentColor => const Color(0xFF9C27B0); // Purple Accent
  Color get scaffoldBackgroundColor => backgroundColor;

  Color get backgroundColor {
    if (_focusMode) return const Color(0xFFF7FAFC);
    if (currentPalette == PaletteType.muted) return const Color(0xFFFBFBF9);
    return const Color(0xFFF8FAFC);
  }

  Color get cardColor => Colors.white;

  // --- Decoration Tokens ---
  BoxDecoration get glassDecoration => BoxDecoration(
    color: Colors.white.withOpacity(_focusMode ? 1.0 : 0.7),
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: primaryColor.withOpacity(0.1)),
    boxShadow: _focusMode ? [] : [
      BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
    ],
  );

  bool get showProgressMarkers => _traits.isADHD;
  bool get enableTTS => _traits.isDyslexic;
  
  // Helper for bento grid colors if needed
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
        background: backgroundColor,
      ),
    );
  }
}
