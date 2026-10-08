/// No-op on non-web targets.
///
/// Native apps have no URL to keep tidy: there is no address bar, so the
/// distinction between `/login` and `/#/login` does not exist. Phases 0-10 are
/// web-only, but the conditional import exists so adding native platforms in
/// Phase 11 is not a compile error.
void configureUrlStrategy() {}
