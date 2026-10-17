import 'package:flutter_test/flutter_test.dart';
import 'package:teven_app/routing/app_router.dart';
import 'package:teven_app/screens/users/user_list_screen.dart'
    show invitationUrl;

/// How the invite link is built — task 5.10, pinned by task 5.13.
///
/// **Plain Dart, not widget tests, and that is the whole reason this is a
/// separate file.** `Uri.base` is not overridable, and under `flutter test` it
/// is a `file:` URI — measured, not assumed:
///
/// ```
/// Uri.base = file:///Users/pforhan/dev/pforhan/teven/flutter_app/
/// ```
///
/// So the `http`/`https` branch of `_appOrigin` — the one that runs in
/// production, the one `UserList.tsx` was actually ported from, the one that
/// decides whether an invitee gets `https://teven.example/register?token=…` or
/// a bare relative `/register?token=…` — **cannot be reached by any widget test
/// in this repo**, no matter how it is written.
///
/// The widget-level consequence is that every link asserted here and in
/// `user_list_screen_test.dart` has an empty origin. That is not a weakness of
/// those tests as long as this file exists: it pins the branch they cannot see,
/// and `invitationUrl`'s `base` parameter exists so this file can reach it
/// without a second copy of the function to keep in step.
void main() {
  const token = '5bd54d87-7846-4770-90f7-e1167b20f3a8';

  group('the origin comes from the base uri', () {
    test('https, which is what production runs on', () {
      expect(
        invitationUrl(token, base: Uri.parse('https://teven.example/users')),
        'https://teven.example/register?token=$token',
      );
    });

    test('http, which is what local verification runs on', () {
      // `docker-compose.yml` publishes port 2022 over plain HTTP, so this is
      // the branch every `./teven up` browser pass actually takes.
      expect(
        invitationUrl(token, base: Uri.parse('http://localhost:2022/users')),
        'http://localhost:2022/register?token=$token',
      );
    });

    test('a non-default port survives', () {
      // `origin` keeps the port, which is what makes `localhost:2022` work at
      // all — a link to `http://localhost/register` would hit whatever else is
      // on port 80.
      expect(
        invitationUrl(token, base: Uri.parse('http://localhost:8080/')),
        'http://localhost:8080/register?token=$token',
      );
    });

    test('the path, query and fragment of the base are all dropped', () {
      // **The load-bearing case, and the one a naive `Uri.base.toString()` would
      // fail.** On web `Uri.base` is the whole document URL, so a user sitting
      // on `/users` would otherwise email a link to
      // `/users/register?token=…`. The SPA fallback would serve it, the router
      // would not match it, and `App.tsx`'s catch-all would redirect the
      // invitee to `/` — silently discarding the token that is the entire point
      // of the link.
      expect(
        invitationUrl(
          token,
          base: Uri.parse(
            'https://teven.example/users?search=grace#unused-invitations',
          ),
        ),
        'https://teven.example/register?token=$token',
      );
    });

    test('a scheme a browser cannot open falls back to its authority', () {
      // A native URL scheme is not worth much to an invitee, who opens the link
      // in a browser — but an origin that names *nothing* is worth even less,
      // and `hasAuthority` at least produces something a platform may hand off.
      expect(
        invitationUrl(token, base: Uri.parse('teven://app/users')),
        'teven://app/register?token=$token',
      );
    });

    test('no usable origin yields a relative link rather than a crash', () {
      // The branch every widget test in this repo exercises, and the one the
      // `Uri.base.origin` crash used to be waiting on. Relative is a real
      // degradation and a deliberate one: an invitee can resolve
      // `/register?token=…` against whatever page they are on, whereas a thrown
      // [StateError] takes down the screen listing their colleagues'
      // invitations.
      //
      // **`file:` with an empty authority is its own case**, and it is the one
      // this function got wrong until task 5.13's test found it. `file:///…`
      // *has* an authority — an empty one — so a `hasAuthority` guard produces
      // the origin `"file://"` and a link of `file:///register?token=…`, which
      // no browser opens. A `file:` URI is what `flutter test` runs against, so
      // every widget test in this repo was asserting against that link.
      expect(
        invitationUrl(token, base: Uri.parse('file:///srv/teven/users')),
        '/register?token=$token',
      );
      expect(
        invitationUrl(token, base: Uri.parse('mailto:someone@example.com')),
        '/register?token=$token',
      );
    });

    test('a file uri with a real host keeps it', () {
      // The other side of the empty-authority rule, so the fix above cannot be
      // read as "never trust a `file:` URI" — it trusts the authority, not the
      // scheme.
      expect(
        invitationUrl(token, base: Uri.parse('file://host/srv/teven')),
        'file://host/register?token=$token',
      );
    });

    test('the default is the running app\'s own address', () {
      // Pins that [base] is optional and defaults to [Uri.base], so the
      // production call sites — two of them, and the copy button must not be
      // able to disagree with the displayed text — are calling this function and
      // not something around it.
      expect(invitationUrl(token), invitationUrl(token, base: Uri.base));
      expect(invitationUrl(token), contains(AppRoutes.register));
    });
  });

  group('the token is carried as a query parameter', () {
    test('and parses back out of the url', () {
      // Asserted by parsing rather than by substring, because the substring
      // version passes for a link that has the token somewhere in the path or
      // the fragment — which the acceptance screen would silently ignore.
      final url = invitationUrl(
        token,
        base: Uri.parse('https://teven.example/users'),
      );
      final parsed = Uri.parse(url);

      expect(parsed.queryParameters['token'], token);
      expect(parsed.path, AppRoutes.register);
      // Exactly one parameter, so nothing is riding along with it.
      expect(parsed.queryParameters, hasLength(1));
    });

    test('two links differ only by their token', () {
      // Task 5.10's second requirement: "the link is not token-dependent on any
      // in-app state". Two links minted from the same app differ by nothing but
      // the secret, so a link cannot be carrying an id, a route the inviter
      // happened to be on, or a signed-in user's organization.
      const base = 'https://teven.example/users';
      expect(
        invitationUrl(
          'token-a',
          base: Uri.parse(base),
        ).replaceAll('token-a', '…'),
        invitationUrl(
          'token-b',
          base: Uri.parse(base),
        ).replaceAll('token-b', '…'),
      );
    });

    test('a uuid round-trips unencoded', () {
      // `InvitationRoutes` mints `UUID.randomUUID()`, so the interpolated token
      // needs no percent-encoding — and this is the test that says so, rather
      // than leaving it as an assumption in a comment.
      expect(
        invitationUrl(token, base: Uri.parse('https://teven.example/')),
        'https://teven.example/register?token=$token',
      );
      // Nothing in a UUID needs escaping, which is the whole justification for
      // interpolating rather than encoding: the parsed-back value above equals
      // the raw token character for character.
      expect(token, matches(r'^[0-9a-f-]+$'));
    });
  });
}
