import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import 'router.dart';

class UqaabApp extends StatelessWidget {
  const UqaabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Uqaab',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: AppRouter.router,
    );
  }
}