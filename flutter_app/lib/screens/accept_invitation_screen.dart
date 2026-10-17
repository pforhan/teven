import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api/api_exception.dart';
import '../models/invitation.dart';
import '../providers/auth_controller.dart';
import '../providers/service_providers.dart';
import '../widgets/already_logged_in_error.dart';
import '../widgets/error_display.dart';
import '../widgets/validators.dart';

/// Accepts an invitation and creates the account behind it.
///
/// Replaces `AcceptInvitationPage.tsx` — 176 lines. Reachable at
/// `/register?token=...`, outside the authenticated branch
/// (`App.tsx:66`), because the invitee following an emailed link has no session.
///
/// **The query parameter is the reason this route exists as a path.** An
/// invitee opens `/register?token=abc123` in a browser. Task 0.9 established
/// that `usePathUrlStrategy()` has to be configured before `GoRouter` is
/// *constructed*, which is why the token arrives as a real query parameter here
/// and not as a fragment.
///
/// ## Where the two logged-in branches come from
///
/// `AcceptInvitationPage.tsx:27-31` sets `alreadyLoggedIn` from an effect on
/// `userContext`, and `:78-79` sets it again when `acceptInvitation` rejects
/// with `"Cannot accept invitation while logged in."`. Only the first is
/// reproduced here, because the second cannot happen without the first:
/// `InvitationRoutes.kt:46` rejects the caller on the strength of an
/// `AuthContext` principal, which only exists for a token that
/// [userContextProvider] has already resolved. Deriving the flag from the
/// context rather than storing it also means it cannot go stale.
class AcceptInvitationScreen extends ConsumerStatefulWidget {
  const AcceptInvitationScreen({
    super.key,
    required this.token,
    required this.onReturnToApp,
    required this.onAccepted,
  });

  /// The invitation's secret, from `?token=`.
  ///
  /// `null` when the URL carried no token, which the page reports as an error
  /// rather than rendering an empty form.
  final String? token;

  /// Sends the user back into the app. Used by [AlreadyLoggedInError].
  final VoidCallback onReturnToApp;

  /// Called a few seconds after a successful acceptance.
  final VoidCallback onAccepted;

  @override
  ConsumerState<AcceptInvitationScreen> createState() =>
      _AcceptInvitationScreenState();
}

class _AcceptInvitationScreenState
    extends ConsumerState<AcceptInvitationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailController = TextEditingController();
  final _displayNameController = TextEditingController();

  ValidateInvitationResponse? _invitation;
  String? _validationError;
  ApiException? _error;
  String? _successMessage;
  bool _submitting = false;
  bool _obscurePassword = true;

  /// Whether a `validateInvitation` call is in flight.
  ///
  /// See [_body] for why this is not derived from [_invitation].
  bool _validating = false;

  Timer? _redirectTimer;

  @override
  void initState() {
    super.initState();
    final token = widget.token;
    if (token == null || token.isEmpty) {
      // `AcceptInvitationPage.tsx:46` — no token in the URL at all.
      _error = const ApiRequestException('Invitation token not found in URL.');
      return;
    }

    // `AcceptInvitationPage.tsx:38-44`. Fire-and-forget on purpose: the screen
    // has its own loading state, and the outcome lands in `_invitation` or
    // `_validationError`.
    setState(() => _validating = true);
    unawaited(_validate(token));
  }

  @override
  void dispose() {
    _redirectTimer?.cancel();
    _usernameController.dispose();
    _passwordController.dispose();
    _emailController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _validate(String token) async {
    try {
      final response = await ref
          .read(invitationServiceProvider)
          .validateInvitation(token);
      if (mounted) {
        setState(() {
          _invitation = response;
          _validating = false;
        });
      }
    } on ApiException catch (error) {
      // The message is the server's own (`InvitationRoutes.kt:38`), so it is
      // more specific than the React fallback and worth preferring.
      if (mounted) {
        setState(() {
          _validationError = error.message.isEmpty
              ? 'Invalid or expired invitation token.'
              : error.message;
          _validating = false;
        });
      }
    }
  }

  /// Creates the account, then points the user at the login screen.
  ///
  /// `AcceptInvitationPage.tsx:50-86`. The 3-second pause before navigating
  /// (`setTimeout`, `:73`) exists so the success message is readable; it is
  /// reproduced rather than dropped, and the timer is cancelled on dispose so a
  /// navigation that unmounts this screen does not fire a callback against a
  /// dead [State].
  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
      _successMessage = null;
    });

    try {
      final response = await ref
          .read(invitationServiceProvider)
          .acceptInvitation(
            AcceptInvitationRequest(
              token: widget.token!,
              username: _usernameController.text,
              password: _passwordController.text,
              email: _emailController.text,
              displayName: _displayNameController.text,
            ),
          );

      // `AcceptInvitationPage.tsx:71`. **The `else` here is unreachable.** A
      // service-level rejection is converted by `InvitationRoutes.kt:60-62`
      // into an envelope-level failure, which `ApiClient` raises as an
      // `ApiRequestException`, so a `success: false` DTO never reaches the
      // client — see `AcceptInvitationResponse`. The branch is kept because the
      // DTO has the field and dropping it would make a server change look like
      // a no-op here.
      if (response.success) {
        _redirectTimer = Timer(const Duration(seconds: 3), widget.onAccepted);
        if (mounted) {
          setState(
            () => _successMessage =
                response.message ?? 'Invitation accepted! You can now log in.',
          );
        }
      } else if (mounted) {
        setState(
          () => _error = ApiRequestException(
            response.message ?? 'Failed to accept invitation.',
          ),
        );
      }
    } on ApiException catch (error) {
      // The logged-in rejection is not special-cased: it is already subsumed
      // by `userContextProvider` being non-null, which renders
      // [AlreadyLoggedInError] instead of this error. See the class docs.
      if (mounted) {
        setState(() => _error = error);
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // `AcceptInvitationPage.tsx:28` — a signed-in visitor gets the
    // already-logged-in screen and nothing else.
    final alreadyLoggedIn = ref.watch(userContextProvider) != null;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              // `col-md-6` is a percentage of the container, which is unbounded
              // inside the scroll view. Fixed like the login screen's 400px,
              // only wider — this card carries four fields and an invitation
              // summary.
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Accept Invitation',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  // Rendered above the logged-in branch, matching
                  // `AcceptInvitationPage.tsx:95-96` — a signed-in user who
                  // followed a stale link sees both.
                  if (_validationError != null) ...[
                    ErrorDisplay(message: _validationError!),
                    const SizedBox(height: 16),
                  ],
                  if (alreadyLoggedIn)
                    AlreadyLoggedInError(onReturnToApp: widget.onReturnToApp)
                  else ...[
                    if (_error != null) ...[
                      ErrorDisplay.fromException(_error!),
                      const SizedBox(height: 16),
                    ],
                    if (_successMessage != null) ...[
                      _InfoBanner(
                        message: _successMessage!,
                        color: Theme.of(context).colorScheme.primaryContainer,
                        foreground: Theme.of(context)
                            .colorScheme
                            .onPrimaryContainer,
                      ),
                      const SizedBox(height: 16),
                    ],
                    _body(),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The four render states of `AcceptInvitationPage.tsx:103-165`.
  ///
  /// **One deliberate departure from the React ternaries.** `:103-104` picks the
  /// loading box on `!invitationDetails && !validationError`, and neither is set
  /// when the URL carried no token — that path sets the ordinary [error] instead
  /// (`:46`). So the original renders "Invitation token not found in URL."
  /// *and* an indefinite "Loading invitation..." box, one on top of the other,
  /// for a page that will never load anything. Transcribing that produces a
  /// spinner that never stops.
  ///
  /// [_validating] tracks the request itself instead, so the box appears only
  /// while a request is genuinely in flight. Every other state matches: a
  /// validation error replaces it, and the form appears only once an invitation
  /// is known and neither a validation error nor a success message is showing.
  Widget _body() {
    if (_validating) {
      return const _InfoBanner.loading();
    }

    if (_invitation == null) {
      // A validation error or a missing token; both are reported by the box
      // above this one.
      return const SizedBox.shrink();
    }

    if (_successMessage != null || _validationError != null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _InfoBanner(
          message:
              'You have been invited to join '
              '${_invitation!.organizationName} as a '
              '${_invitation!.roleName}.\n'
              'Please create your account below.',
          color: Theme.of(context).colorScheme.primaryContainer,
          foreground: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
        const SizedBox(height: 24),
        Form(
          key: _formKey,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _usernameController,
                  autofillHints: const [
                    AutofillHints.newUsername,
                    AutofillHints.username,
                  ],
                  textInputAction: TextInputAction.next,
                  enabled: !_submitting,
                  decoration: const InputDecoration(labelText: 'Username'),
                  validator: _required,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  autofillHints: const [AutofillHints.newPassword],
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.next,
                  enabled: !_submitting,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    suffixIcon: IconButton(
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      tooltip: _obscurePassword
                          ? 'Show password'
                          : 'Hide password',
                    ),
                  ),
                  validator: _required,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  autofillHints: const [AutofillHints.email],
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  enabled: !_submitting,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: Validators.email,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _displayNameController,
                  autofillHints: const [AutofillHints.name],
                  textInputAction: TextInputAction.done,
                  enabled: !_submitting,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: const InputDecoration(labelText: 'Display Name'),
                  validator: _required,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Accept Invitation'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Stands in for `required` (`AcceptInvitationPage.tsx:120`).
  static String? _required(String? value) =>
      (value == null || value.isEmpty) ? 'This field is required' : null;
}

/// The Bootstrap `alert-info` / `alert-success` boxes on this screen.
class _InfoBanner extends StatelessWidget {
  const _InfoBanner({
    required this.message,
    required this.color,
    required this.foreground,
  }) : loading = false;

  const _InfoBanner.loading()
    : message = 'Loading invitation...',
      color = null,
      foreground = null,
      loading = true;

  final String message;
  final Color? color;
  final Color? foreground;

  /// Whether this is the indeterminate "validating" box, which shows a spinner.
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background = color ?? theme.colorScheme.primaryContainer;
    final onBackground = foreground ?? theme.colorScheme.onPrimaryContainer;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (loading) ...[
            SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: onBackground,
              ),
            ),
            const SizedBox(width: 12),
          ],
          // The invitation summary is two `<p>`s in the React original; the
          // newline between them is the only thing distinguishing them from
          // inside one text node, and `mb-0` on the second meant no gap.
          Expanded(
            child: Text(message, style: TextStyle(color: onBackground)),
          ),
        ],
      ),
    );
  }
}
