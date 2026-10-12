import 'package:flutter/material.dart';

/// Stands in for a screen that has not been ported yet.
///
/// Every route in `App.tsx` is registered from Phase 2 onward, well before the
/// screens themselves exist in Phases 3–8. A route that is missing entirely
/// would fall through to the catch-all and redirect — so a signed-in user
/// clicking "Customers" would be sent back to `/events` with no explanation,
/// and the router tests would have nothing to assert against.
///
/// Naming the route on screen makes the gap visible while it lasts. Each one
/// disappears as its phase lands; `grep PlaceholderScreen` is the checklist.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({
    super.key,
    required this.path,
    this.params = const <String, String>{},
  });

  /// Builds a placeholder whose title is the route path.
  const PlaceholderScreen.route(this.path, {this.params = const {}})
    : super(key: null);

  /// The route path, with its parameter placeholders left intact — `/events/:eventId`
  /// rather than `/events/42`, so it reads as a route rather than a URL.
  final String path;

  /// Resolved path parameters, when the route has any.
  final Map<String, String> params;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(path, style: textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Not ported yet — see FLUTTER-CONVERT.md.',
              style: textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            if (params.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (final entry in params.entries)
                Text(
                  '${entry.key}=${entry.value}',
                  style: textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
