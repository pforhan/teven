import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Tells a signed-in user that they cannot accept an invitation.
///
/// Replaces `AlreadyLoggedInError.tsx` — 16 lines, one Bootstrap `alert-danger`
/// with a heading, a rule, and a link home.
///
/// The link is a callback rather than a route reference. The React original
/// hardcodes `href="/"`, which the router turns into `/events`
/// (`App.tsx:41`); naming that destination here would make this widget depend
/// on `app_router.dart`, which imports the screens that import this widget. The
/// route builder passes the real destination in instead, and a test can assert
/// on it without a router at all.
///
/// **The link is a `TextSpan` with a gesture recognizer, not a `TextButton`.** A
/// button cannot be an inline link: it brings its own chrome (the circular
/// hover/splash blob), it is announced as a button rather than a link, and
/// pushed inline it needs padding hacks that show up as gaps in the sentence.
/// A recognizer span is what `<a>` actually is, and it underlines for free.
/// The cost is a smaller hit area — the word itself rather than a 48dp button —
/// which is the same trade the React original made, and people know how to
/// click a word.
class AlreadyLoggedInError extends StatefulWidget {
  const AlreadyLoggedInError({super.key, required this.onReturnToApp});

  /// Invoked by the "here" link.
  final VoidCallback onReturnToApp;

  @override
  State<AlreadyLoggedInError> createState() => _AlreadyLoggedInErrorState();
}

class _AlreadyLoggedInErrorState extends State<AlreadyLoggedInError> {
  late final TapGestureRecognizer _link = TapGestureRecognizer()
    // Reads [widget] at tap time rather than capturing the callback at
    // construction, so a parent that rebuilds with a new closure does not leave
    // the link calling a stale one.
    ..onTap = () => widget.onReturnToApp();

  @override
  void dispose() {
    _link.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Semantics(
      // The React original sets `role="alert"`, which makes screen readers
      // announce the box the moment it appears rather than leaving the user to
      // find it.
      container: true,
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Already Logged In',
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.onErrorContainer,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You are already logged in. You cannot accept an invitation '
              'while you are logged in.',
              style: TextStyle(color: colorScheme.onErrorContainer),
            ),
            const SizedBox(height: 12),
            Divider(color: colorScheme.onErrorContainer.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            // The `<p class="mb-0">` and the inline `<a>` become one wrapped
            // sentence with a link inside it. A [Row] of two separate widgets
            // would break the line at the viewport edge and push the link onto
            // its own row.
            Text.rich(
              TextSpan(
                style: TextStyle(color: colorScheme.onErrorContainer),
                children: [
                  const TextSpan(
                    text: 'You can return to the application by clicking ',
                  ),
                  // The link text must not begin or end with whitespace: the
                  // underline would start in blank space, and the recognizer's
                  // hit box would extend past the word. The separating space
                  // belongs to the sentence above, not to the link.
                  TextSpan(
                    text: 'here',
                    recognizer: _link,
                    style: TextStyle(
                      // The link colour, not [error]. Bootstrap puts a link
                      // inside `.alert-danger` in the same blue it uses
                      // everywhere else, and an error-coloured link on a pink
                      // background is both the wrong look and the *worst*
                      // possible contrast against the dark red body text —
                      // it makes the link less findable, not more.
                      color: colorScheme.primary,
                      // The underline is what marks this as clickable at rest,
                      // and it carries that signal without relying on colour.
                      decoration: TextDecoration.underline,
                      decorationColor: colorScheme.primary,
                    ),
                  ),
                  const TextSpan(text: '.'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
