import 'package:flutter_web_plugins/url_strategy.dart';

/// Serves clean paths (`/login`, `/register?token=...`) instead of the default
/// hash strategy (`/#/login`).
///
/// Required, not cosmetic. Two things depend on it:
///
/// 1. Invitation links are built as `${window.location.origin}/register?token=...`
///    (`UserList.tsx:157`, `CreateInvitationForm.tsx:74`). The backend's SPA
///    fallback (`Routing.kt:56-58`, `default("index.html")`) only rewrites
///    unmatched *paths*; a fragment is never sent to the server. Under the hash
///    strategy an invite link would load the app root with the token stranded in
///    the fragment, where nothing reads it.
/// 2. Path-based URLs match the 21 routes being ported in Phase 2, which were
///    copied from the React app's `App.tsx` paths verbatim.
void configureUrlStrategy() => usePathUrlStrategy();
