import 'package:flutter/material.dart';

/// Temporary scaffold target for Phase 0.
///
/// Task 0.9 adds the real routing via `go_router`; this screen exists so the
/// shell renders and `flutter analyze` has something to check.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Teven')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Flutter conversion in progress',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Scaffold only — see FLUTTER-CONVERT.md for progress.',
              style: TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}
