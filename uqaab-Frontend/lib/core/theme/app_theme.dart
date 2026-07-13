// import 'package:flutter/material.dart';
// import '../constants/app_colors.dart';

// class AppTheme {
//   static ThemeData get darkTheme {
//     return ThemeData(
//       brightness: Brightness.dark,

//       // GLOBAL FONT
//       fontFamily: 'Inter',

//       scaffoldBackgroundColor: Colors.transparent,

//       primaryColor: AppColors.primary,

//       colorScheme: const ColorScheme.dark(
//         primary: AppColors.primary,
//         secondary: AppColors.primaryLight,
//         surface: AppColors.backgroundSecondary,
//         error: AppColors.danger,
//       ),

//       // ===============================
//       // TEXT THEME
//       // ===============================

//       textTheme: const TextTheme(
//         headlineLarge: TextStyle(
//           fontFamily: 'Inter',
//           fontWeight: FontWeight.w700,
//           fontSize: 28,
//           color: AppColors.textPrimary,
//         ),

//         headlineMedium: TextStyle(
//           fontFamily: 'Inter',
//           fontWeight: FontWeight.w700,
//           fontSize: 22,
//           color: AppColors.textPrimary,
//         ),

//         bodyLarge: TextStyle(
//           fontFamily: 'Inter',
//           fontWeight: FontWeight.w400,
//           fontSize: 16,
//           color: AppColors.textPrimary,
//         ),

//         bodyMedium: TextStyle(
//           fontFamily: 'Inter',
//           fontWeight: FontWeight.w400,
//           fontSize: 14,
//           color: AppColors.textSecondary,
//         ),

//         labelLarge: TextStyle(
//           fontFamily: 'Inter',
//           fontWeight: FontWeight.w600,
//           fontSize: 16,
//           color: Colors.white,
//         ),
//       ),

//       // ===============================
//       // APPBAR
//       // ===============================

//       appBarTheme: const AppBarTheme(
//         backgroundColor: Colors.transparent,
//         elevation: 0,
//         centerTitle: false,
//         iconTheme: IconThemeData(color: AppColors.textPrimary),
//         titleTextStyle: TextStyle(
//           fontFamily: 'Inter',
//           color: AppColors.textPrimary,
//           fontSize: 20,
//           fontWeight: FontWeight.w700,
//         ),
//       ),

//       // ===============================
//       // BOTTOM NAV
//       // ===============================

//       bottomNavigationBarTheme: const BottomNavigationBarThemeData(
//         backgroundColor: AppColors.backgroundSecondary,
//         selectedItemColor: AppColors.primary,
//         unselectedItemColor: AppColors.textSecondary,
//         type: BottomNavigationBarType.fixed,
//         elevation: 8,
//       ),

//       // ===============================
//       // CARDS
//       // ===============================

//       cardTheme: CardThemeData(
//         color: AppColors.backgroundSecondary,
//         elevation: 0,
//         shape: RoundedRectangleBorder(
//           borderRadius: BorderRadius.circular(12),
//           side: const BorderSide(color: AppColors.borderDefault),
//         ),
//       ),

//       // ===============================
//       // INPUT FIELDS (Glassmorphism)
//       // ===============================

//       inputDecorationTheme: InputDecorationTheme(
//         filled: true,
//         fillColor: Colors.white.withOpacity(0.05),

//         border: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(14),
//           borderSide: const BorderSide(
//             color: AppColors.borderDefault,
//             width: 1,
//           ),
//         ),

//         enabledBorder: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(14),
//           borderSide: const BorderSide(
//             color: AppColors.borderDefault,
//             width: 1,
//           ),
//         ),

//         focusedBorder: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(14),
//           borderSide: const BorderSide(
//             color: AppColors.borderFocused,
//             width: 1.5,
//           ),
//         ),

//         hintStyle: const TextStyle(
//           fontFamily: 'Inter',
//           fontWeight: FontWeight.w400,
//           color: AppColors.textMuted,
//         ),

//         prefixIconColor: AppColors.textSecondary,

//         contentPadding:
//             const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
//       ),

//       // ===============================
//       // BUTTON
//       // ===============================

//       elevatedButtonTheme: ElevatedButtonThemeData(
//         style: ElevatedButton.styleFrom(
//           backgroundColor: Colors.transparent,
//           shadowColor: Colors.transparent,
//           minimumSize: const Size(double.infinity, 52),
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(14),
//           ),
//           textStyle: const TextStyle(
//             fontFamily: 'Inter',
//             fontWeight: FontWeight.w600,
//             fontSize: 16,
//           ),
//         ),
//       ),

//       // ===============================
//       // FAB
//       // ===============================

//       floatingActionButtonTheme: const FloatingActionButtonThemeData(
//         backgroundColor: AppColors.primary,
//         foregroundColor: Colors.white,
//         shape: RoundedRectangleBorder(
//           borderRadius: BorderRadius.all(Radius.circular(16)),
//         ),
//       ),

//       // ===============================
//       // DIALOG
//       // ===============================

//       dialogTheme: DialogThemeData(
//         backgroundColor: AppColors.backgroundSecondary,
//         shape: RoundedRectangleBorder(
//           borderRadius: BorderRadius.circular(16),
//         ),
//       ),

//       // ===============================
//       // SNACKBAR
//       // ===============================

//       snackBarTheme: SnackBarThemeData(
//         backgroundColor: AppColors.backgroundSecondary,
//         contentTextStyle: const TextStyle(
//           fontFamily: 'Inter',
//           color: AppColors.textPrimary,
//         ),
//         shape: RoundedRectangleBorder(
//           borderRadius: BorderRadius.circular(8),
//         ),
//         behavior: SnackBarBehavior.floating,
//       ),
//     );
//   }
// }

import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,

      // GLOBAL FONT — light sans-serif for body
      fontFamily: 'Inter',

      scaffoldBackgroundColor: AppColors.backgroundPrimary,

      primaryColor: AppColors.primary,

      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        secondary: AppColors.primaryLight,
        surface: AppColors.backgroundSecondary,
        error: AppColors.danger,
        onPrimary: AppColors.textOnDark,
        onSurface: AppColors.textPrimary,
      ),

      // ===============================
      // TEXT THEME
      // Serif for headings, sans-serif for body
      // ===============================

      textTheme: const TextTheme(
        // Large serif headings — editorial magazine feel
        headlineLarge: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w700,
          fontSize: 30,
          color: AppColors.textPrimary,
          letterSpacing: -0.5,
          height: 1.2,
        ),

        headlineMedium: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w700,
          fontSize: 22,
          color: AppColors.textPrimary,
          letterSpacing: -0.3,
          height: 1.3,
        ),

        headlineSmall: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w600,
          fontSize: 18,
          color: AppColors.textPrimary,
          letterSpacing: -0.2,
        ),

        // Title styles — still serif for numbers/labels
        titleLarge: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w600,
          fontSize: 18,
          color: AppColors.textPrimary,
        ),

        titleMedium: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w600,
          fontSize: 15,
          color: AppColors.textPrimary,
          letterSpacing: 0.1,
        ),

        // Body — light Inter sans-serif
        bodyLarge: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w300,
          fontSize: 16,
          color: AppColors.textPrimary,
          height: 1.6,
        ),

        bodyMedium: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w300,
          fontSize: 14,
          color: AppColors.textSecondary,
          height: 1.5,
        ),

        bodySmall: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w400,
          fontSize: 12,
          color: AppColors.textTertiary,
          letterSpacing: 0.3,
        ),

        // Labels / buttons
        labelLarge: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w500,
          fontSize: 15,
          color: AppColors.textOnDark,
          letterSpacing: 0.8,
        ),

        labelMedium: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w500,
          fontSize: 12,
          color: AppColors.textSecondary,
          letterSpacing: 0.5,
        ),

        labelSmall: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w400,
          fontSize: 10,
          color: AppColors.textMuted,
          letterSpacing: 0.8,
        ),
      ),

      // ===============================
      // APPBAR — clean, no shadow
      // ===============================

      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.backgroundPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        titleTextStyle: TextStyle(
          fontFamily: 'Inter',
          color: AppColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),

      // ===============================
      // BOTTOM NAV
      // ===============================

      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.darkSurface, // deep charcoal nav
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textOnDarkMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      // ===============================
      // CARDS — crisp thin border, no radius, no shadow
      // ===============================

      cardTheme: const CardThemeData(
        color: AppColors.backgroundSecondary,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero, // no radius — editorial
          side: BorderSide(
            color: AppColors.borderDefault,
            width: 1,
          ),
        ),
      ),

      // ===============================
      // INPUT FIELDS — editorial minimal
      // ===============================

      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: AppColors.inputBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.zero, // no radius
          borderSide: BorderSide(
            color: AppColors.borderDefault,
            width: 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(
            color: AppColors.borderDefault,
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(
            color: AppColors.borderFocused,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(
            color: AppColors.danger,
            width: 1,
          ),
        ),
        hintStyle: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w300,
          color: AppColors.textMuted,
          fontSize: 14,
        ),
        labelStyle: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w400,
          color: AppColors.textSecondary,
          fontSize: 13,
          letterSpacing: 0.5,
        ),
        prefixIconColor: AppColors.textSecondary,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),

      // ===============================
      // ELEVATED BUTTON — flat, tan/gold, no radius
      // ===============================

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary, // editorial tan/gold
          foregroundColor: AppColors.textOnDark,
          shadowColor: Colors.transparent,
          elevation: 0,
          minimumSize: const Size(double.infinity, 52),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.zero, // no radius
          ),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w500,
            fontSize: 15,
            letterSpacing: 0.8,
          ),
        ),
      ),

      // ===============================
      // OUTLINED BUTTON
      // ===============================

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(
            color: AppColors.borderStrong,
            width: 1,
          ),
          minimumSize: const Size(double.infinity, 52),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.zero,
          ),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w500,
            fontSize: 15,
            letterSpacing: 0.5,
          ),
        ),
      ),

      // ===============================
      // TEXT BUTTON
      // ===============================

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w500,
            fontSize: 14,
            letterSpacing: 0.3,
          ),
        ),
      ),

      // ===============================
      // FAB — charcoal, no radius
      // ===============================

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(30)),
        ),
      ),

      // ===============================
      // DIALOG
      // ===============================

      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.backgroundPrimary,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(
            color: AppColors.borderDefault,
            width: 1,
          ),
        ),
        titleTextStyle: TextStyle(
          fontFamily: 'Georgia',
          fontWeight: FontWeight.w700,
          fontSize: 20,
          color: AppColors.textPrimary,
        ),
        contentTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w300,
          fontSize: 14,
          color: AppColors.textSecondary,
        ),
      ),

      // ===============================
      // SNACKBAR
      // ===============================

      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.darkSurface,
        contentTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w400,
          color: AppColors.textOnDark,
          fontSize: 14,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
        ),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
      ),

      // ===============================
      // DIVIDER — thin, warm border
      // ===============================

      dividerTheme: const DividerThemeData(
        color: AppColors.borderDefault,
        thickness: 1,
        space: 1,
      ),

      // ===============================
      // LIST TILE
      // ===============================

      listTileTheme: const ListTileThemeData(
        textColor: AppColors.textPrimary,
        iconColor: AppColors.textSecondary,
        tileColor: Colors.transparent,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),

      // ===============================
      // CHIP
      // ===============================

      chipTheme: const ChipThemeData(
        backgroundColor: AppColors.backgroundSecondary,
        labelStyle: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w400,
          fontSize: 13,
          color: AppColors.textPrimary,
        ),
        side: BorderSide(color: AppColors.borderDefault, width: 1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
        ),
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),

      // ===============================
      // SWITCH / CHECKBOX / RADIO
      // ===============================

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.primary;
          return AppColors.textMuted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primary.withOpacity(0.3);
          }
          return AppColors.borderDefault;
        }),
      ),

      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.primary;
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(AppColors.textOnDark),
        side: const BorderSide(color: AppColors.borderDefault, width: 1.5),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
        ),
      ),
    );
  }

  // Keep darkTheme alias pointing to lightTheme so existing
  // references in main.dart don't break during migration.
  static ThemeData get darkTheme => lightTheme;
}
