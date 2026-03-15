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
  bool _isDarkMode = false;
  bool _highContrast = false;
  bool _readingRuler = false;
  double _fontSizeScale = 1.0; // 0.8 = small, 1.0 = normal, 1.3 = large

  UserTraits get traits => _traits;
  bool get useDyslexicFont => _useDyslexicFont || _traits.isDyslexic;
  bool get focusMode => _focusMode;
  bool get isDarkMode => _isDarkMode;
  bool get highContrast => _highContrast;
  bool get readingRuler => _readingRuler;
  double get fontSizeScale => _fontSizeScale;

  // ── Palette Resolution ────────────────────────────────────────────────────
  PaletteType get currentPalette {
    if (_manualPalette != null) return _manualPalette!;
    return (_traits.isAutistic || _traits.isDyslexic)
        ? PaletteType.muted
        : PaletteType.vibrant;
  }

  bool get isAutoDetectPalette => _manualPalette == null;

  // ── Setters ───────────────────────────────────────────────────────────────
  void setTraits(UserTraits newTraits) {
    if (_traits == newTraits) return;
    _traits = newTraits;
    AppLogger.info('Theme traits updated: ${newTraits.learningProfileName}',
        tag: 'DynamicTheme');
    notifyListeners();
  }

  void toggleDyslexicFont() {
    _useDyslexicFont = !_useDyslexicFont;
    AppLogger.info('Dyslexic font: $_useDyslexicFont', tag: 'DynamicTheme');
    notifyListeners();
  }

  void toggleFocusMode() {
    _focusMode = !_focusMode;
    AppLogger.info('Focus Mode: $_focusMode', tag: 'DynamicTheme');
    notifyListeners();
  }

  void toggleDarkMode() {
    _isDarkMode = !_isDarkMode;
    AppLogger.info('Dark Mode: $_isDarkMode', tag: 'DynamicTheme');
    notifyListeners();
  }

  void toggleHighContrast() {
    _highContrast = !_highContrast;
    AppLogger.info('High Contrast: $_highContrast', tag: 'DynamicTheme');
    notifyListeners();
  }

  void toggleReadingRuler() {
    _readingRuler = !_readingRuler;
    AppLogger.info('Reading Ruler: $_readingRuler', tag: 'DynamicTheme');
    notifyListeners();
  }

  void setFontSizeScale(double scale) {
    _fontSizeScale = scale.clamp(0.8, 1.4);
    AppLogger.info('Font scale: $_fontSizeScale', tag: 'DynamicTheme');
    notifyListeners();
  }

  void setManualPalette(PaletteType? type) {
    _manualPalette = type;
    AppLogger.info('Manual palette: $type', tag: 'DynamicTheme');
    notifyListeners();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PALETTE 1 — AUTISTIC: Calm Sage
  // ══════════════════════════════════════════════════════════════════════════
  static const Color _autisticBg = Color(0xFFE8F0E8);
  static const Color _autisticPrimary = Color(0xFF4A7C59);
  static const Color _autisticAccent = Color(0xFF6B8E6B);
  static const Color _autisticXP = Color(0xFF4A7C59);
  static const Color _autisticText = Color(0xFF2D4A2D);

  // ══════════════════════════════════════════════════════════════════════════
  // PALETTE 2 — DYSLEXIC: Warm Beige
  // ══════════════════════════════════════════════════════════════════════════
  static const Color _dyslexicBg = Color(0xFFF5F0E8);
  static const Color _dyslexicPrimary = Color(0xFFC8956C);
  static const Color _dyslexicAccent = Color(0xFFE07B39);
  static const Color _dyslexicXP = Color(0xFFE07B39);
  static const Color _dyslexicText = Color(0xFF4A3728);

  // ══════════════════════════════════════════════════════════════════════════
  // PALETTE 3 — ADHD: Electric Focus
  // ══════════════════════════════════════════════════════════════════════════
  static const Color _adhdBg = Color(0xFFEBF4FF);
  static const Color _adhdPrimary = Color(0xFF3A86FF);
  static const Color _adhdAccent = Color(0xFFFF006E);
  static const Color _adhdXP = Color(0xFFFF006E);
  static const Color _adhdText = Color(0xFF0A2540);

  // ══════════════════════════════════════════════════════════════════════════
  // PALETTE 4 — DYSPRAXIC: Bold Action
  // ══════════════════════════════════════════════════════════════════════════
  static const Color _dyspraxicBg = Color(0xFFF3EEFF);
  static const Color _dyspraxicPrimary = Color(0xFF8338EC);
  static const Color _dyspraxicAccent = Color(0xFFFF9500);
  static const Color _dyspraxicXP = Color(0xFFFF9500);
  static const Color _dyspraxicText = Color(0xFF1A0A2E);

  // ══════════════════════════════════════════════════════════════════════════
  // FOCUS MODE
  // ══════════════════════════════════════════════════════════════════════════
  static const Color _focusBg = Color(0xFFF7FAFC);
  static const Color _focusPrimary = Color(0xFF2D3748);

  // ── Public Color Tokens ───────────────────────────────────────────────────

  Color get primaryColor {
    if (_highContrast && _isDarkMode) return const Color(0xFF00E5FF);
    if (_highContrast) return Colors.black;
    if (_focusMode) return _focusPrimary;
    if (_traits.isAutistic && _traits.isADHD) return _adhdPrimary;
    if (_traits.isAutistic) return _autisticPrimary;
    if (_traits.isDyslexic) return _dyslexicPrimary;
    if (_traits.isADHD) return _adhdPrimary;
    if (_traits.isDyspraxic) return _dyspraxicPrimary;
    if (_manualPalette == PaletteType.vibrant) return _adhdPrimary;
    if (_manualPalette == PaletteType.muted) return _autisticPrimary;
    return _adhdPrimary;
  }

  Color get xpAccentColor {
    if (_highContrast) return _isDarkMode ? Colors.yellow : Colors.black;
    if (_traits.isAutistic && !_traits.isADHD) return _autisticXP;
    if (_traits.isDyslexic && !_traits.isADHD) return _dyslexicXP;
    if (_traits.isADHD) return _adhdXP;
    if (_traits.isDyspraxic) return _dyspraxicXP;
    return _adhdXP;
  }

  Color get secondaryColor {
    if (_highContrast) return _isDarkMode ? Colors.white70 : Colors.black87;
    if (_traits.isAutistic) return _autisticAccent;
    if (_traits.isDyslexic) return _dyslexicAccent;
    if (_traits.isADHD) return _adhdAccent;
    if (_traits.isDyspraxic) return _dyspraxicAccent;
    return _adhdAccent;
  }

  Color get backgroundColor {
    if (_highContrast && _isDarkMode) return Colors.black;
    if (_highContrast) return Colors.white;
    if (_isDarkMode) return const Color(0xFF12121A);
    if (_focusMode) return _focusBg;
    if (_traits.isAutistic && _traits.isADHD) return _autisticBg;
    if (_traits.isAutistic) return _autisticBg;
    if (_traits.isDyslexic) return _dyslexicBg;
    if (_traits.isADHD) return _adhdBg;
    if (_traits.isDyspraxic) return _dyspraxicBg;
    if (_manualPalette == PaletteType.muted) return _autisticBg;
    if (_manualPalette == PaletteType.vibrant) return _adhdBg;
    return const Color(0xFFF8FAFC);
  }

  Color get scaffoldBackgroundColor => backgroundColor;

  Color get cardColor {
    if (_highContrast && _isDarkMode) return const Color(0xFF0A0A0A);
    if (_highContrast) return Colors.white;
    return _isDarkMode ? const Color(0xFF1E1E2E) : Colors.white;
  }

  Color get cardTextColor =>
      _isDarkMode ? const Color(0xFFE8E8F0) : onSurfaceTextColor;

  Color get onSurfaceTextColor {
    if (_highContrast && _isDarkMode) return Colors.white;
    if (_highContrast) return Colors.black;
    if (_isDarkMode) return const Color(0xFFE8E8F0);
    if (_focusMode) return const Color(0xFF1A202C);
    if (_traits.isAutistic) return _autisticText;
    if (_traits.isDyslexic) return _dyslexicText;
    if (_traits.isADHD) return _adhdText;
    if (_traits.isDyspraxic) return _dyspraxicText;
    return const Color(0xFF1A1A2E);
  }

  // ── Decoration Tokens ─────────────────────────────────────────────────────
  BoxDecoration get glassDecoration {
    final isMuted = currentPalette == PaletteType.muted;
    if (_highContrast) {
      return BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isDarkMode ? Colors.white : Colors.black,
          width: 2,
        ),
      );
    }
    return BoxDecoration(
      color: cardColor,
      borderRadius: BorderRadius.circular(16),
      border: isMuted
          ? Border.all(color: primaryColor.withValues(alpha: 0.15), width: 0.5)
          : Border.all(color: primaryColor.withValues(alpha: 0.2)),
      boxShadow: (_focusMode || isMuted)
          ? []
          : [
              BoxShadow(
                color: primaryColor.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
    );
  }

  // ── Button Tokens ─────────────────────────────────────────────────────────
  BorderRadius get buttonBorderRadius =>
      BorderRadius.circular(_traits.isDyspraxic ? 16.0 : 12.0);

  double get buttonMinHeight => _traits.isDyspraxic ? 64.0 : 52.0;
  double get buttonMinWidth => _traits.isDyspraxic ? 140.0 : 100.0;
  double get buttonMinSize => buttonMinHeight;
  double get interactivePadding => _traits.isDyspraxic ? 24.0 : 14.0;

  Color get buttonColor => primaryColor;

  ButtonStyle get primaryButtonStyle => ElevatedButton.styleFrom(
        backgroundColor: buttonColor,
        foregroundColor: _highContrast
            ? (_isDarkMode ? Colors.black : Colors.white)
            : Colors.white,
        minimumSize: Size(buttonMinWidth, buttonMinHeight),
        padding: EdgeInsets.symmetric(
          horizontal: interactivePadding * 1.5,
          vertical: interactivePadding * 0.75,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: buttonBorderRadius,
          side: _highContrast
              ? BorderSide(color: onSurfaceTextColor, width: 2)
              : BorderSide.none,
        ),
        elevation: currentPalette == PaletteType.muted ? 0 : 3,
        shadowColor: primaryColor.withValues(alpha: 0.3),
      );

  // ── Typography — font size scales with _fontSizeScale ────────────────────
  TextStyle get bodyStyle {
    final base = useDyslexicFont ? 18.0 : 16.0;
    return GoogleFonts.lexend(
      fontSize: base * _fontSizeScale,
      letterSpacing: useDyslexicFont ? 0.6 : 0.0,
      height: useDyslexicFont ? 1.8 : 1.5,
      fontWeight: FontWeight.w400,
      color: onSurfaceTextColor,
    );
  }

  TextStyle get titleStyle {
    final base = 24.0 * _fontSizeScale;
    if (useDyslexicFont) {
      return GoogleFonts.lexend(
        fontSize: base,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: onSurfaceTextColor,
      );
    }
    return GoogleFonts.outfit(
      fontSize: base,
      fontWeight: FontWeight.w600,
      color: onSurfaceTextColor,
    );
  }

  TextStyle get buttonTextStyle => GoogleFonts.lexend(
        fontSize: 16.0 * _fontSizeScale,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      );

  // ── Feature Flags ─────────────────────────────────────────────────────────
  bool get showProgressMarkers => _traits.isADHD || _traits.isDyspraxic;
  bool get enableTTS => _traits.isDyslexic;

  // ── Palette Helpers ───────────────────────────────────────────────────────
  Color getAdaptivePaletteColor(int index) {
    final List<Color> colors = currentPalette == PaletteType.vibrant
        ? [_adhdPrimary, _dyspraxicPrimary, _adhdAccent, _dyspraxicAccent]
        : [
            _autisticPrimary,
            _autisticAccent,
            _dyslexicPrimary,
            _dyslexicAccent
          ];
    return colors[index % colors.length];
  }

  // ── ThemeData ─────────────────────────────────────────────────────────────
  ThemeData get themeData {
    final isMuted = currentPalette == PaletteType.muted;

    return ThemeData(
      useMaterial3: true,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: backgroundColor,
      cardColor: cardColor,
      textTheme: TextTheme(
        bodyMedium: bodyStyle,
        titleLarge: titleStyle,
        labelLarge: buttonTextStyle,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: backgroundColor,
        titleTextStyle: titleStyle,
        elevation: 0,
        scrolledUnderElevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: onSurfaceTextColor),
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: isMuted ? 0 : 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: isMuted
              ? BorderSide(
                  color: primaryColor.withValues(alpha: 0.15), width: 0.5)
              : BorderSide.none,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(style: primaryButtonStyle),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: xpAccentColor,
        linearTrackColor: xpAccentColor.withValues(alpha: 0.15),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return Colors.grey[400];
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primaryColor;
          return _isDarkMode ? Colors.grey[700] : Colors.grey[300];
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primaryColor;
          return _isDarkMode ? Colors.grey[600] : Colors.grey[400];
        }),
      ),
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: _isDarkMode ? Brightness.dark : Brightness.light,
        primary: primaryColor,
        secondary: secondaryColor,
        surface: cardColor,
        onSurface: onSurfaceTextColor,
        onPrimary: Colors.white,
      ),
    );
  }
}
