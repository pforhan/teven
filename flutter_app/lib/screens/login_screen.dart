import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api/api_exception.dart';
import '../providers/auth_controller.dart';
import '../widgets/error_display.dart';

/// The login screen.
///
/// Replaces `Auth.tsx` — 71 lines of a single card, no register link and no
/// "forgot password", since neither exists in the React app.
///
/// Deliberately narrower than the rest of the port in one respect: **there is
/// no `_Form` abstraction here.** Task 5.1 settles that convention once, for
/// seven forms, and binding login to a convention chosen afterwards would mean
/// rewriting it. What the screen does reproduce is the behaviour — see
/// [_submit] — and the card sizing, fixed up for small viewports.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _submitting = false;
  bool _obscurePassword = true;
  ApiException? _error;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Authenticates, then reloads the context.
  ///
  /// `Auth.tsx:27-30` calls `AuthService.login` and then
  /// `refetchUserContext()`; [AuthController.login] does both, and the router
  /// reacts to the resulting context change by leaving `/login` on its own.
  /// Nothing here navigates — doing so would race the redirect that lands the
  /// user on `/events`.
  ///
  /// Every failure is funnelled into [_error] and shown through
  /// [ErrorDisplay], matching `Auth.tsx:20-27`. The React version branches
  /// between `ApiErrorWithDetails`, a bare `Error`, and a fallback string; the
  /// exception hierarchy already collapses those three into one type.
  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await ref
          .read(authControllerProvider.notifier)
          .login(
            username: _usernameController.text,
            password: _passwordController.text,
          );
    } on ApiException catch (error) {
      // Guard against the screen being torn down mid-request — the router
      // redirect can dispose it as soon as the context resolves.
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
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            // The React card is `width: '25rem'`, which is 400px of horizontal
            // padding-and-all on a 360px phone — the layout overflows its own
            // container. A max width plus symmetric padding keeps the desktop
            // card the same size and lets the mobile view go edge to edge.
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _formKey,
                child: AutofillGroup(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Login',
                        style: Theme.of(context).textTheme.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      if (_error != null) ...[
                        ErrorDisplay.fromException(_error!),
                        const SizedBox(height: 16),
                      ],
                      TextFormField(
                        controller: _usernameController,
                        autofillHints: const [AutofillHints.username],
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Username',
                        ),
                        validator: _required,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        autofillHints: const [AutofillHints.password],
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          suffixIcon: IconButton(
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
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
                      const SizedBox(height: 24),
                      FilledButton(
                        // Disabled while in flight so a double-tap cannot fire
                        // two logins — the React form has no such guard, and a
                        // second POST races the first one's token write.
                        onPressed: _submitting ? null : _submit,
                        child: _submitting
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Login'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Stands in for the React `required` attribute (`Auth.tsx:45,57`).
  static String? _required(String? value) =>
      (value == null || value.isEmpty) ? 'This field is required' : null;
}
