import 'package:flutter/material.dart';

import '../core/api/api_exception.dart';

/// A failure to show the user: a summary, plus details behind a disclosure.
///
/// Replaces `ErrorDisplay.tsx`, which renders `Error: {message}` with the
/// details collapsed behind a "Show Details" toggle.
///
/// Shared rather than per-screen, because the React original is shared and
/// every form in Phase 5 needs the same treatment.
class ErrorDisplay extends StatelessWidget {
  const ErrorDisplay({super.key, required this.message, this.details});

  /// Builds from an API exception, showing [ApiException.details] when present.
  ///
  /// Note `Application.kt:55-75` puts `cause.stackTraceToString()` in
  /// `details` on a 500, so server internals reach the client. The React app
  /// shows them behind a toggle and so does this, deliberately — task 9.9
  /// decides whether to suppress it.
  factory ErrorDisplay.fromException(ApiException error) =>
      ErrorDisplay(message: error.message, details: error.details);

  final String message;
  final String? details;

  @override
  Widget build(BuildContext context) {
    if (details == null || details!.isEmpty) {
      return _Banner(message: message);
    }

    return _DisclosureBanner(message: message, details: details!);
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => _ErrorSurface(
    child: Text(
      'Error: $message',
      style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
    ),
  );
}

/// The collapsible-details half of [ErrorDisplay], matching `ErrorDisplay.tsx`
/// lines 14-27.
///
/// A local `useState` in the React original becomes state in a [StatefulWidget]
/// here. An `ExpansionTile` would be fewer lines, but it changes the control
/// and the copy; the button-label parity matters more than the line count when
/// the point is that the port is faithful.
class _DisclosureBanner extends StatefulWidget {
  const _DisclosureBanner({required this.message, required this.details});

  final String message;
  final String details;

  @override
  State<_DisclosureBanner> createState() => _DisclosureBannerState();
}

class _DisclosureBannerState extends State<_DisclosureBanner> {
  bool _showDetails = false;

  @override
  Widget build(BuildContext context) {
    return _ErrorSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Error: ${widget.message}',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                // The React button is `btn-sm`; this keeps the tap target at
                // the 48dp minimum once vertical padding is factored in.
                minimumSize: const Size(64, 48),
              ),
              onPressed: () => setState(() => _showDetails = !_showDetails),
              child: Text(_showDetails ? 'Hide Details' : 'Show Details'),
            ),
          ),
          if (_showDetails)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                widget.details,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}

class _ErrorSurface extends StatelessWidget {
  const _ErrorSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(4),
      ),
      child: child,
    );
  }
}
