// import 'package:flutter/material.dart';

// class AppColors {

//   // =========================================================
//   // PREMIUM DARK SYSTEM (NEW)
//   // =========================================================

//   static const Color backgroundPrimary = Color(0xFF020617);
//   static const Color backgroundSecondary = Color(0xFF0F172A);
//   static const Color backgroundTertiary = Color(0xFF1E293B);

//   static const LinearGradient backgroundGradient = LinearGradient(
//     begin: Alignment.topCenter,
//     end: Alignment.bottomCenter,
//     colors: [
//       Color(0xFF0F172A),
//       Color(0xFF020617),
//     ],
//   );

//   static const LinearGradient buttonGradient = LinearGradient(
//     colors: [
//       Color(0xFF3B82F6),
//       Color(0xFF60A5FA),
//     ],
//     begin: Alignment.centerLeft,
//     end: Alignment.centerRight,
//   );

//   // =========================================================
//   // ORIGINAL COLORS (DO NOT REMOVE - used across project)
//   // =========================================================

//   static const Color background = Color(0xFF0D1117);
//   static const Color surface = Color(0xFF1C1F26);
//   static const Color surfaceLight = Color(0xFF252830);
//   static const Color surfaceBorder = Color(0xFF30363D);

//   // Primary
//   static const Color primary = Color(0xFF3B82F6);
//   static const Color primaryLight = Color(0xFF60A5FA);
//   static const Color primaryDark = Color(0xFF304FFE);

//   // Status
//   static const Color success = Color(0xFF10B981);
//   static const Color warning = Color(0xFFF59E0B);
//   static const Color danger = Color(0xFFEF4444);
//   static const Color info = Color(0xFF378ADD);

//   // Specific
//   static const Color dispatch = Color(0xFFEA580C);
//   static const Color droneFlying = Color(0xFF378ADD);
//   static const Color liveRed = Color(0xFFE53935);
//   static const Color liveGreen = Color(0xFF43A047);

//   // Text
//   static const Color textPrimary = Color(0xFFF8FAFC);
//   static const Color textSecondary = Color(0xFF94A3B8);
//   static const Color textTertiary = Color(0xFF565B6E);
//   static const Color textDanger = Color(0xFFE24B4A);
//   static const Color textMuted = Color(0xFF475569);

//   // Grid
//   static const Color gridCameraGreen = Color(0xFF1D9E75);
//   static const Color gridDroneBlue = Color(0xFF378ADD);
//   static const Color gridEmpty = Color(0xFF252830);
//   static const Color gridWaypoint = Color(0xFF3B82F6);
//   static const Color gridXLaser = Color(0xFFE24B4A);
//   static const Color gridYLaser = Color(0xFF1D9E75);

//   // Input
//   static const Color inputBackground = Color(0xFF161B22);
//   static const Color inputBorder = Color(0xFF30363D);
//   static const Color inputFocusBorder = Color(0xFF3B82F6);

//   // Borders
//   static const Color borderDefault = Color(0xFF1E293B);
//   static const Color borderFocused = Color(0xFF3B82F6);
// }

import 'package:flutter/material.dart';

class AppColors {
  // =========================================================
  // WARM EDITORIAL SYSTEM (NEW)
  // =========================================================
  static const Color backgroundPrimary   = Color(0xFFFAF9F6); // warm off-white
  static const Color backgroundSecondary = Color(0xFFF0EDE6); // slightly deeper off-white
  static const Color backgroundTertiary  = Color(0xFFE8E3D9); // warm light tan

  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFFAF9F6),
      Color(0xFFF0EDE6),
    ],
  );

  static const LinearGradient buttonGradient = LinearGradient(
    colors: [
      Color(0xFFC5A880), // muted editorial tan/gold
      Color(0xFFD4BC99), // lighter gold
    ],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  // =========================================================
  // CORE PALETTE
  // =========================================================
  static const Color background    = Color(0xFFFAF9F6);
  static const Color surface       = Color(0xFFF0EDE6);
  static const Color surfaceLight  = Color(0xFFE8E3D9);
  static const Color surfaceBorder = Color(0xFFD4C9B8);

  // Primary — editorial tan/gold
  static const Color primary      = Color(0xFFC5A880);
  static const Color primaryLight = Color(0xFFD4BC99);
  static const Color primaryDark  = Color(0xFFAA8E68);

  // Dark surfaces (for overlays, nav, cards with dark bg)
  static const Color darkSurface       = Color(0xFF1C1C1C); // deep charcoal
  static const Color darkSurfaceLight  = Color(0xFF2A2A2A);
  static const Color darkSurfaceBorder = Color(0xFF3A3A3A);

  // =========================================================
  // STATUS COLORS
  // =========================================================
  static const Color success  = Color(0xFF4A7C59); // muted green
  static const Color warning  = Color(0xFFC8963E); // warm amber
  static const Color danger   = Color(0xFFB84C4C); // muted red
  static const Color info     = Color(0xFF6A8EAE); // muted blue

  // =========================================================
  // SPECIFIC / SEMANTIC
  // =========================================================
  static const Color dispatch    = Color(0xFFC8693E);
  static const Color droneFlying = Color(0xFF6A8EAE);
  static const Color liveRed     = Color(0xFFB84C4C);
  static const Color liveGreen   = Color(0xFF4A7C59);

  // =========================================================
  // TEXT
  // =========================================================
  static const Color textPrimary   = Color(0xFF1C1C1C); // deep charcoal
  static const Color textSecondary = Color(0xFF5A5248); // warm medium gray
  static const Color textTertiary  = Color(0xFF8A7E72); // warm light gray
  static const Color textMuted     = Color(0xFFAA9E92); // very muted warm
  static const Color textDanger    = Color(0xFFB84C4C);

  // Text on dark surfaces
  static const Color textOnDark        = Color(0xFFFAF9F6);
  static const Color textOnDarkMuted   = Color(0xFFBBB0A4);

  // =========================================================
  // GRID
  // =========================================================
  static const Color gridCameraGreen = Color(0xFF4A7C59);
  static const Color gridDroneBlue   = Color(0xFF6A8EAE);
  static const Color gridEmpty       = Color(0xFFE8E3D9);
  static const Color gridWaypoint    = Color(0xFFC5A880);
  static const Color gridXLaser      = Color(0xFFB84C4C);
  static const Color gridYLaser      = Color(0xFF4A7C59);

  // =========================================================
  // INPUT
  // =========================================================
  static const Color inputBackground = Color(0xFFF5F2EC);
  static const Color inputBorder     = Color(0xFFD4C9B8);
  static const Color inputFocusBorder = Color(0xFFC5A880);

  // =========================================================
  // BORDERS
  // =========================================================
  static const Color borderDefault = Color(0xFFD4C9B8);
  static const Color borderFocused = Color(0xFFC5A880);
  static const Color borderStrong  = Color(0xFF1C1C1C);
}