import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/url_strategy.dart';
import 'core/theme/teven_theme.dart';
import 'providers/auth_controller.dart';
import 'routing/app_router.dart';

void main() {
  // Must run before `runApp`. See `configureUrlStrategy`.
  configureUrlStrategy();
  runApp(const ProviderScope(child: TevenApp()));
}

class TevenApp extends ConsumerWidget {
  const TevenApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Teven',
      debugShowCheckedModeBanner: false,
      theme: TevenTheme.light(),
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) => _AuthGate(child: child),
    );
  }
}

/// Holds the screen back while the boot context fetch is in flight.
///
/// `App.tsx:34-36` short-circuits the whole route tree on `loading` and
/// renders a plain "Loading...". The router's redirect has the same job for
/// navigation (see `_redirect`), but a redirect alone only protects routes that
/// redirect — a deep link that is public, such as `/register`, would render
/// with a null context behind it. So the gate lives here too.
class _AuthGate extends ConsumerWidget {
  const _AuthGate({required this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(authControllerProvider).isLoading) {
      return Scaffold(
        body: Center(
          child: Text(
            'Loading...',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      );
    }

    return child ?? const SizedBox.shrink();
  }
}
