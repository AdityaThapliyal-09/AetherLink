// AetherLink — Application Entry Point
// Initializes services and launches the app.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'features/home/aether_provider.dart';
import 'presentation/navigation/app_router.dart';
import 'presentation/theme/aether_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Force portrait orientation for better readability in emergency scenarios
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: AetherTheme.bgSurface,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  runApp(const AetherLinkApp());
}

class AetherLinkApp extends StatelessWidget {
  const AetherLinkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AetherProvider()..initialize(),
      child: MaterialApp.router(
        title: 'AetherLink',
        debugShowCheckedModeBanner: false,
        theme: AetherTheme.dark,
        routerConfig: appRouter,
      ),
    );
  }
}
