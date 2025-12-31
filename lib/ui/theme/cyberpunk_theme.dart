import 'package:flutter/material.dart';

/// 赛博朋克主题
class CyberpunkTheme {
  // 赛博朋克配色方案
  static const Color neonPink = Color(0xFFFF00FF);
  static const Color neonCyan = Color(0xFF00FFFF);
  static const Color neonGreen = Color(0xFF00FF41);
  static const Color neonYellow = Color(0xFFFFF700);
  static const Color darkBg = Color(0xFF0A0A0A);
  static const Color darkSurface = Color(0xFF1A1A1A);
  static const Color darkSurfaceVariant = Color(0xFF2A2A2A);
  static const Color accentPurple = Color(0xFF9D00FF);
  static const Color accentBlue = Color(0xFF0066FF);

  /// 赛博朋克深色主题
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBg,
      
      // 配色方案
      colorScheme: const ColorScheme.dark(
        primary: neonCyan,
        secondary: neonPink,
        tertiary: neonGreen,
        error: Color(0xFFFF1744),
        surface: darkSurface,
        surfaceVariant: darkSurfaceVariant,
        onPrimary: darkBg,
        onSecondary: darkBg,
        onSurface: Colors.white,
        onError: Colors.white,
      ),

      // AppBar 主题
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: darkSurface,
        foregroundColor: neonCyan,
        titleTextStyle: const TextStyle(
          color: neonCyan,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),

      // 卡片主题
      cardTheme: CardTheme(
        elevation: 0,
        color: darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(
            color: neonCyan,
            width: 1,
          ),
        ),
      ),

      // 按钮主题
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: neonCyan,
          foregroundColor: darkBg,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
      ),

      // 输入框主题
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: neonCyan, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: neonCyan, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: neonPink, width: 2),
        ),
        labelStyle: const TextStyle(color: neonCyan),
        hintStyle: TextStyle(color: Colors.grey[400]),
      ),

      // 文本主题
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          color: neonCyan,
          fontSize: 32,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
        displayMedium: TextStyle(
          color: neonCyan,
          fontSize: 28,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
        displaySmall: TextStyle(
          color: neonCyan,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
        headlineMedium: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        titleLarge: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        bodyLarge: TextStyle(
          color: Colors.white,
          fontSize: 16,
        ),
        bodyMedium: TextStyle(
          color: Colors.white70,
          fontSize: 14,
        ),
      ),

      // Switch 主题
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return neonCyan;
          }
          return Colors.grey;
        }),
        trackColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return neonCyan.withOpacity(0.3);
          }
          return Colors.grey.withOpacity(0.3);
        }),
      ),

      // Divider 主题
      dividerTheme: const DividerThemeData(
        color: neonCyan,
        thickness: 1,
        space: 1,
      ),
    );
  }

  /// 赛博朋克渐变装饰
  static BoxDecoration neonGradient({
    AlignmentGeometry begin = Alignment.topLeft,
    AlignmentGeometry end = Alignment.bottomRight,
  }) {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: begin,
        end: end,
        colors: [
          neonCyan.withOpacity(0.1),
          neonPink.withOpacity(0.1),
          neonGreen.withOpacity(0.1),
        ],
      ),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: neonCyan.withOpacity(0.3),
        width: 1,
      ),
    );
  }

  /// 赛博朋克发光效果
  static List<BoxShadow> neonGlow(Color color) {
    return [
      BoxShadow(
        color: color.withOpacity(0.5),
        blurRadius: 20,
        spreadRadius: 2,
      ),
      BoxShadow(
        color: color.withOpacity(0.3),
        blurRadius: 40,
        spreadRadius: 4,
      ),
    ];
  }
}

