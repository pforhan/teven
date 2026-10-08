import 'package:flutter/material.dart';

import 'core/theme/teven_theme.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const TevenApp());
}

class TevenApp extends StatelessWidget {
  const TevenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Teven',
      debugShowCheckedModeBanner: false,
      theme: TevenTheme.light(),
      home: const HomeScreen(),
    );
  }
}
