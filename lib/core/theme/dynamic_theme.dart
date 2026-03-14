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

  // ── Palette Resolution ────────────────────────────────────────────────────
  PaletteType get currentPalette {
    if (_manualPalette != null) return _manualPalette!;
    return (_traits.isAutistic || _traits.isDyslexic)
        ? PaletteType.muted
        : PaletteType.vibrant;
  }

  // ← NEW: used by profile screen auto-detect toggle
  bool get isAutoDetectPalette => _manualPalette == null;

  // ── Trait Setters ─────────────────────────────────────────────────────────
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

  void setManualPalette(PaletteType? type) {
    _manualPalette = type;
    AppLogger.info('Manual palette: $type', tag: 'DynamicTheme');
    notifyListeners();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PALETTE 1 — AUTISTIC: Calm Sage
  // Soft greens, no harsh contrast, minimal borders
  // ══════════════════════════════════════════════════════════════════════════
  static const Color _autisticBg = Color(0xFFE8F0E8);
  static const Color _autisticPrimary = Color(0xFF4A7C59);
  static const Color _autisticAccent = Color(0xFF6B8E6B);
  static const Color _autisticXP = Color(0xFF4A7C59);
  static const Color _autisticText = Color(0xFF2D4A2D);

  // ══════════════════════════════════════════════════════════════════════════
  // PALETTE 2 — DYSLEXIC: Warm Beige
  // Warm tones, cream background, readable terracotta
  // ══════════════════════════════════════════════════════════════════════════
  static const Color _dyslexicBg = Color(0xFFF5F0E8);
  static const Color _dyslexicPrimary = Color(0xFFC8956C);
  static const Color _dyslexicAccent = Color(0xFFE07B39);
  static const Color _dyslexicXP = Color(0xFFE07B39);
  static const Color _dyslexicText = Color(0xFF4A3728);

  // ══════════════════════════════════════════════════════════════════════════
  // PALETTE 3 — ADHD: Electric Focus
  // High energy blue + hot pink XP for dopamine reward
  // ══════════════════════════════════════════════════════════════════════════
  static const Color _adhdBg = Color(0xFFEBF4FF);
  static const Color _adhdPrimary = Color(0xFF3A86FF);
  static const Color _adhdAccent = Color(0xFFFF006E);
  static const Color _adhdXP = Color(0xFFFF006E);
  static const Color _adhdText = Color(0xFF0A2540);

  // ══════════════════════════════════════════════════════════════════════════
  // PALETTE 4 — DYSPRAXIC: Bold Action
  // Deep purple + vivid orange XP, large tap targets
  // ══════════════════════════════════════════════════════════════════════════
  static const Color _dyspraxicBg = Color(0xFFF3EEFF);
  static const Color _dyspraxicPrimary = Color(0xFF8338EC);
  static const Color _dyspraxicAccent = Color(0xFFFF9500);
  static const Color _dyspraxicXP = Color(0xFFFF9500);
  static const Color _dyspraxicText = Color(0xFF1A0A2E);

  // ══════════════════════════════════════════════════════════════════════════
  // FOCUS MODE — Industrial Slate
  // ══════════════════════════════════════════════════════════════════════════
  static const Color _focusBg = Color(0xFFF7FAFC);
  static const Color _focusPrimary = Color(0xFF2D3748);

  // ── Public Color Tokens ───────────────────────────────────────────────────

  Color get primaryColor {
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
    if (_traits.isAutistic && !_traits.isADHD) return _autisticXP;
    if (_traits.isDyslexic && !_traits.isADHD) return _dyslexicXP;
    if (_traits.isADHD) return _adhdXP;
    if (_traits.isDyspraxic) return _dyspraxicXP;
    return _adhdXP;
  }

  Color get secondaryColor {
    if (_traits.isAutistic) return _autisticAccent;
    if (_traits.isDyslexic) return _dyslexicAccent;
    if (_traits.isADHD) return _adhdAccent;
    if (_traits.isDyspraxic) return _dyspraxicAccent;
    return _adhdAccent;
  }

  Color get backgroundColor {
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
  Color get cardColor => Colors.white;

  Color get onSurfaceTextColor {
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
        foregroundColor: Colors.white,
        minimumSize: Size(buttonMinWidth, buttonMinHeight),
        padding: EdgeInsets.symmetric(
          horizontal: interactivePadding * 1.5,
          vertical: interactivePadding * 0.75,
        ),
        shape: RoundedRectangleBorder(borderRadius: buttonBorderRadius),
        elevation: currentPalette == PaletteType.muted ? 0 : 3,
        shadowColor: primaryColor.withValues(alpha: 0.3),
      );

  // ── Typography ────────────────────────────────────────────────────────────
  TextStyle get bodyStyle {
    return GoogleFonts.lexend(
      fontSize: useDyslexicFont ? 18 : 16,
      letterSpacing: useDyslexicFont ? 0.6 : 0.0,
      height: useDyslexicFont ? 1.8 : 1.5,
      fontWeight: FontWeight.w400,
      color: onSurfaceTextColor,
    );
  }

  TextStyle get titleStyle {
    if (useDyslexicFont) {
      return GoogleFonts.lexend(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: onSurfaceTextColor,
      );
    }
    return GoogleFonts.outfit(
      fontSize: 24,
      fontWeight: FontWeight.w600,
      color: onSurfaceTextColor,
    );
  }

  TextStyle get buttonTextStyle => GoogleFonts.lexend(
        fontSize: 16,
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

      // ← XP bar wired to xpAccentColor
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: xpAccentColor,
        linearTrackColor: xpAccentColor.withValues(alpha: 0.15),
      ),

      // ← Switch follows primaryColor — fixes both toggles
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return Colors.grey[400];
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primaryColor;
          return Colors.grey[300];
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primaryColor;
          return Colors.grey[400];
        }),
      ),

      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        primary: primaryColor,
        secondary: secondaryColor,
        surface: cardColor,
        onSurface: onSurfaceTextColor,
        onPrimary: Colors.white,
      ),
    );
  }
}
