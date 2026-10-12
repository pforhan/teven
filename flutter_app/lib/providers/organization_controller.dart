import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/organization.dart';
import 'service_providers.dart';

/// The organization the super-admin is currently working in, or `null`.
///
/// Replaces `OrganizationContext` (`OrganizationContext.tsx`), which held the
/// same single value in React state and mirrored it into `localStorage`.
///
/// Scoped to super-admins only — `MainLayout.tsx` shows everyone else a static
/// label — but the persistence is unconditional, matching the React original,
/// which also wrote the key whoever set it.
final organizationControllerProvider =
    AsyncNotifierProvider<OrganizationController, OrganizationResponse?>(
      OrganizationController.new,
    );

class OrganizationController extends AsyncNotifier<OrganizationResponse?> {
  /// Mirrors `OrganizationContext.tsx:11-15`: restore from storage on boot,
  /// seeded synchronously in React and asynchronously here.
  ///
  /// `localStorage` is a synchronous store, so React could initialize during
  /// the first render. `SharedPreferences` is async on every platform
  /// including web, where it is backed by `localStorage` but only through a
  /// future. Hence [AsyncNotifier] — the value is genuinely not known during
  /// the first frame.
  @override
  Future<OrganizationResponse?> build() async {
    final prefs = await ref.watch(sharedPreferencesProvider.future);
    return _decode(prefs.getString(storageKey));
  }

  /// Sets the selected organization and persists it.
  ///
  /// Persistence is awaited before the state is published, matching
  /// `OrganizationContext.tsx:18-24`, where `setItem` runs synchronously inside
  /// the setter. Publishing first and writing second would let a fast reload
  /// land between the two and read the old value back.
  ///
  /// A `null` [organization] clears the key rather than storing `"null"` —
  /// `removeItem` in the original.
  Future<void> select(OrganizationResponse? organization) async {
    final prefs = await ref.read(sharedPreferencesProvider.future);

    if (organization == null) {
      await prefs.remove(storageKey);
    } else {
      await prefs.setString(storageKey, jsonEncode(organization.toJson()));
    }

    state = AsyncData(organization);
  }

  /// Parses a stored value, tolerating anything unreadable.
  ///
  /// The original calls a bare `JSON.parse` on whatever is in
  /// `localStorage` (`OrganizationContext.tsx:12`), so a value written by an
  /// older build — or edited by hand — throws during the first render and
  /// takes the whole app down. A stale selection is recoverable; a white
  /// screen is not.
  static OrganizationResponse? _decode(String? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) {
        return null;
      }
      return OrganizationResponse.fromJson(json);
    } on FormatException {
      return null;
    }
  }

  /// Storage key, identical to the React original's.
  ///
  /// Preserved so a user switching between the two apps mid-migration keeps
  /// their selection. Both sides store plain `jsonEncode` of the same fields.
  static const String storageKey = 'selectedOrganization';
}

/// The selected organization, or `null`. The convenience accessor replacing
/// `useOrganization()`.
final selectedOrganizationProvider = Provider<OrganizationResponse?>(
  (ref) => ref.watch(organizationControllerProvider).value,
);
