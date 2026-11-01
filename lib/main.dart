import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'chat_page.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: C.night,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(const WayfarerApp());
}

class WayfarerApp extends StatelessWidget {
  const WayfarerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wayfarer',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const ChatPage(),
    );
  }
}
