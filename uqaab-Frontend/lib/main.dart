// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:provider/provider.dart';
// import 'app/app.dart';
// import 'app/app_providers.dart';
// import 'core/services/notification_service.dart';

// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   await NotificationService().init();

//   await SystemChrome.setPreferredOrientations([
//     DeviceOrientation.portraitUp,
//     DeviceOrientation.portraitDown,
//   ]);

//   SystemChrome.setSystemUIOverlayStyle(
//     const SystemUiOverlayStyle(
//       statusBarColor: Colors.transparent,
//       statusBarIconBrightness: Brightness.light,
//       systemNavigationBarColor: Color(0xFF0D1117),
//       systemNavigationBarIconBrightness: Brightness.light,
//     ),
//   );

//   runApp(
//     MultiProvider(
//       providers: AppProviders.providers,
//       child: const UqaabApp(),
//     ),
//   );
// }
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'app/app.dart';
import 'app/app_providers.dart';
import 'app/router.dart';
import 'core/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await NotificationService().init();

  NotificationService().onAlertTapped = (alertId) {
    AppRouter.router.push('/alerts/$alertId');
  };

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0D1117),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(
    MultiProvider(
      providers: AppProviders.providers,
      child: const UqaabApp(),
    ),
  );
}
