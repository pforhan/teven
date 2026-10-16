import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/services/list_query.dart';
import '../../models/invitation.dart';
import '../../models/organization.dart';
import '../../models/permissions.dart';
import '../../models/user.dart';
import '../../providers/auth_controller.dart';
import '../../providers/organization_controller.dart';
import '../../providers/service_providers.dart';
import '../../providers/user_list.dart';
import '../../routing/app_router.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/debounced_search_field.dart';
import '../../widgets/error_display.dart';
import '../../widgets/list_screen_header.dart';
import '../../widgets/paged_list_view.dart';
import '../../widgets/record_link_button.dart';
import '../../widgets/responsive_list_view.dart';

/// The user list — task 4.7.
///
/// `UserList.tsx` (264 lines), the largest of the four list screens, and the
/// only one that renders **two** tables: unused invitations above the users,
/// both inside one route. That is why this screen is not a copy of the customer
/// one with different columns.
///
/// Four things here are worth knowing before reading the code:
///
/// - **The two deletes do different things, and only one of them works.**
///   `UserList.tsx:81` deletes a user through an endpoint that does not exist
///   (task 10.12); `UserList.tsx:95` deletes an invitation, which is real. Both
///   go through the shared [confirmDestructiveAction], and both refetch rather
///   than navigate away — the *consequence* of a delete stays at the call site,
///   which is the whole reason the dialog is shared (task 4.8). This is 4.8's
///   fifth and sixth wired flows; only Phase 7's event delete remains.
/// - **The organization column is conditional.** `UserList.tsx:142-152` adds it
///   only for a caller holding `VIEW_USERS_GLOBAL`. An organization-scoped
///   admin sees users in their own organization already, so the column would
///   be four identical values — which is also why [userPageProvider] scopes the
///   query to the selected organization for exactly that caller.
/// - **"Create Invitation" is not here.** `UserList.tsx:206` toggles an inline
///   `CreateInvitationForm` (182 lines), which is task 5.7. There is no route
///   for it in `App.tsx` — the React original renders it in place — so there is
///   nothing to navigate to, and a button that opens nothing is worse than no
///   button. It returns with the form that owns it.
/// - **The invite link is built from `Uri.base`,** not from
///   `window.location.origin` as `UserList.tsx:157` does. Task 5.10 asks for
///   that; doing it here rather than waiting means the link this screen hands a
///   user is correct on every platform from the start.
class UserListScreen extends ConsumerStatefulWidget {
  const UserListScreen({super.key});

  @override
  ConsumerState<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends ConsumerState<UserListScreen> {
  /// How long the "Copied!" label stays up. `UserList.tsx:160` — `setTimeout`
  /// at 2000ms.
  static const Duration _copiedIndicatorDuration = Duration(seconds: 2);

  String _searchTerm = '';

  /// `UserList.tsx:27` — the list opens sorted by username ascending, which is
  /// one of the three columns `UserDao` actually honours.
  String _sortBy = 'username';
  SortOrder _sortOrder = SortOrder.asc;

  /// The invitation whose link was last copied, or null. `UserList.tsx:154`'s
  /// `copiedInvitationId`.
  int? _copiedInvitationId;

  Timer? _copiedTimer;

  /// An error from a mutation — either delete. The fetches' errors live in
  /// their own providers. See the same split on the customer screen.
  ApiException? _actionError;

  /// The query built during the last build, kept so the user-delete handler can
  /// reach the same provider the screen is watching. See the customer screen
  /// for why rebuilding it in the handler would be a second copy of the scoping
  /// rules.
  ///
  /// **Only the user delete uses this.** The invitation delete refetches the
  /// invitations instead, which are a separate provider and a separate
  /// collection — see `_confirmDeleteInvitation`.
  ListQuery? _query;

  @override
  void dispose() {
    // A pending reset would fire into a disposed state, exactly as the search
    // field's debounce would.
    _copiedTimer?.cancel();
    super.dispose();
  }

  /// `UserList.tsx:110-117`: re-tapping the active column reverses it, and a
  /// different column starts ascending.
  void _onSort(String key) {
    setState(() {
      if (_sortBy == key) {
        _sortOrder = _sortOrder == SortOrder.asc
            ? SortOrder.desc
            : SortOrder.asc;
      } else {
        _sortBy = key;
        _sortOrder = SortOrder.asc;
      }
    });
  }

  /// The user delete. `UserList.tsx:78-91`.
  ///
  /// **This request 404s** — see [UserService.deleteUser] and task 10.12. The
  /// React original behaved identically: the button was there, the call went
  /// nowhere, and the caught error went into the shared `error` state the table
  /// rendered. That is what the action-error banner below is.
  Future<void> _confirmDeleteUser(UserResponse user) async {
    final confirmed = await confirmDestructiveAction(
      context,
      title: 'Delete user',
      message:
          'Are you sure you want to delete ${user.username}? This cannot be '
          'undone.',
    );

    if (!confirmed || !mounted) return;

    try {
      await ref.read(userServiceProvider).deleteUser(user.userId);
      // `fetchUsers()` in the original — a reload back to the first page. See
      // `PagedListController.reload` for why an invalidation would be wrong once
      // there is more than one page.
      await ref.read(userPageProvider(_query!).notifier).reload();
      setState(() => _actionError = null);
    } on ApiException catch (error) {
      if (mounted) setState(() => _actionError = error);
    }
  }

  /// The invitation delete. `UserList.tsx:93-108`.
  ///
  /// Refetches the invitations rather than the users, for the reason 4.8 keeps
  /// the consequence at the call site: this deletes a different collection
  /// from the one the row sits in, and the two lists are independent fetches.
  Future<void> _confirmDeleteInvitation(InvitationResponse invitation) async {
    final confirmed = await confirmDestructiveAction(
      context,
      title: 'Delete invitation',
      message:
          'Are you sure you want to delete this invitation? Anyone who has '
          'it will no longer be able to register.',
    );

    if (!confirmed || !mounted) return;

    try {
      await ref
          .read(invitationServiceProvider)
          .deleteInvitation(invitation.invitationId);
      // `fetchInvitations()` in the original.
      ref.invalidate(unusedInvitationsProvider);
      setState(() => _actionError = null);
    } on ApiException catch (error) {
      if (mounted) setState(() => _actionError = error);
    }
  }

  /// Copies an invite link to the clipboard. `UserList.tsx:156-164`.
  ///
  /// The origin comes from [Uri.base] rather than `window.location.origin`
  /// (task 5.10): `Uri.base` is the document's own address on web and the
  /// running app's elsewhere, so one expression is right on both, and an
  /// invitee always receives a link they can open in a browser.
  Future<void> _copyInvitationLink(InvitationResponse invitation) async {
    final url = invitationUrl(invitation.token);

    // The React original logs a copy failure to the console and says nothing.
    // A user watching a button that visibly does nothing is worse than being
    // told why, so the failure goes to the same banner as a failed delete.
    try {
      await Clipboard.setData(ClipboardData(text: url));
    } on PlatformException catch (error) {
      if (mounted) {
        setState(
          () => _actionError = ApiRequestException(
            'Could not copy the invitation link',
            details: error.message,
          ),
        );
      }
      return;
    }

    if (!mounted) return;
    setState(() {
      _copiedInvitationId = invitation.invitationId;
      // Restart rather than stack, so a second copy re-arms the timer instead
      // of racing the first one's reset.
      _copiedTimer?.cancel();
      _copiedTimer = Timer(_copiedIndicatorDuration, () {
        if (mounted) setState(() => _copiedInvitationId = null);
      });
    });
  }

  /// The user columns. `UserList.tsx:119-152`.
  ///
  /// Three of the five are sortable, and those three are exactly the ones
  /// `UserDao.getUsers` switches on (`username`, `displayName`, `email`) —
  /// verified for task 4.11. Roles and organization are not sortable because
  /// the server cannot sort by them.
  ///
  /// **The `flex` values are the whole reason this is not a copy of the other
  /// three screens' column lists**, and they came out of a browser screenshot
  /// rather than out of the source. At a 1419px window — the narrowest this
  /// table ever renders, since the extended rail takes 256px and the card
  /// breakpoint is 1100 — the default "first column gets two shares" gave
  /// Username, holding "alice" and "bob", the largest column, and split the
  /// remainder four ways. Email wrapped as `alice@greenvistas.co` / `m` and
  /// `TEST_ORG_Green` / `Vistas Landscaping` broke across two lines each.
  ///
  /// The weights are proportional to the longest realistic value per column,
  /// not to the average: an email address is bounded by nothing in particular,
  /// while a display name and a role name are short by nature. **They are a
  /// judgement, and the test only pins the symptom they were chosen to fix** —
  /// that a real email and a real organization name fit on one line — not the
  /// exact ratios. Narrowing the browser is the only way to revisit them.
  List<ListColumn<UserResponse>> _userColumns({
    required bool canViewGlobal,
  }) => [
    ListColumn<UserResponse>(
      key: 'username',
      label: 'Username',
      sortable: true,
      flex: 2,
      render: (context, user) => RecordLinkButton(
        label: user.username,
        onPressed: () => context.go(AppRoutes.userDetails(user.userId)),
      ),
    ),
    ListColumn<UserResponse>(
      key: 'displayName',
      label: 'Display Name',
      sortable: true,
      flex: 2,
      text: (user) => user.displayName,
    ),
    ListColumn<UserResponse>(
      key: 'email',
      label: 'Email',
      sortable: true,
      flex: 3,
      text: (user) => user.email,
    ),
    // `UserList.tsx:139` — `user.roles.join(', ')`. Not sortable: roles live
    // in a join table and `UserDao` has no case for them. Narrowest column,
    // because a role name is one word.
    ListColumn<UserResponse>(
      key: 'roles',
      label: 'Roles',
      flex: 1,
      text: (user) => user.roles.join(', '),
    ),
    // `UserList.tsx:142-152` — appended only for a global viewer. Widest,
    // because this is the one column holding a free-text name written by
    // whoever created the organization.
    if (canViewGlobal)
      ListColumn<UserResponse>(
        key: 'organization',
        label: 'Organization',
        flex: 4,
        render: (context, user) => RecordLinkButton(
          label: user.organization.name,
          onPressed: () => context.go(
            AppRoutes.organizationDetails(user.organization.organizationId),
          ),
        ),
      ),
  ];

  /// The invitation columns. `UserList.tsx:166-195`.
  ///
  /// None are sortable — `TableView` only renders a sort control on a column
  /// marked `sortable`, and none of these are. The React table also had a
  /// hand-rolled "Actions" column holding a labelled delete button;
  /// [ResponsiveListView]'s action list replaces it, which is what the other
  /// three screens did.
  /// Builds the provider key from this screen's own state.
  ///
  /// **`limit` and `offset` are deliberately absent** — they belong to
  /// `PagedListController`, which applies the page size and advances the offset
  /// itself. See the customer screen for why.
  ListQuery _buildQuery(OrganizationResponse? organization) => ListQuery(
    search: _searchTerm.isEmpty ? null : _searchTerm,
    sortBy: _sortBy,
    sortOrder: _sortOrder,
    // `UserList.tsx:39` — only ever non-null for a super-admin, since that is
    // the only case in which a selection exists to scope by.
    organizationId: organization?.organizationId,
  );

  /// The invitation columns. `UserList.tsx:166-195`.
  List<ListColumn<InvitationResponse>> _invitationColumns() => [
    ListColumn<InvitationResponse>(
      key: 'roleName',
      label: 'Role',
      text: (invitation) => invitation.roleName,
    ),
    // `UserList.tsx:168` renders `invitation.note || 'N/A'`, so a null note
    // is shown as text rather than as an empty cell.
    ListColumn<InvitationResponse>(
      key: 'note',
      label: 'Note',
      text: (invitation) => invitation.note ?? 'N/A',
    ),
    ListColumn<InvitationResponse>(
      key: 'invitationUrl',
      label: 'Link',
      render: (context, invitation) => _InvitationLinkCell(
        invitation: invitation,
        copied: _copiedInvitationId == invitation.invitationId,
        onCopy: () => _copyInvitationLink(invitation),
      ),
    ),
    ListColumn<InvitationResponse>(
      key: 'expiresAt',
      label: 'Expires',
      text: (invitation) => formatDate(invitation.expiresAt),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final gate = ref.watch(permissionGateProvider);
    // `UserList.tsx:24-25`. Wider than any other list screen's gate: either
    // scope can manage users, matching `App.tsx:62`'s OR-semantics on the
    // create route.
    final canManage = gate.hasAny([
      Permission.manageUsersGlobal,
      Permission.manageUsersOrganization,
    ]);
    final canViewGlobal = gate.has(Permission.viewUsersGlobal);
    final organization = ref.watch(selectedOrganizationProvider);

    // `UserList.tsx:53-55` fetches invitations only for a manager, and
    // `UserList.tsx:223` renders the table only when there is something in it.
    // Gating the watch rather than the fetch keeps an unauthorized caller from
    // issuing a request that would 403.
    final invitations = canManage
        ? ref.watch(unusedInvitationsProvider)
        : const AsyncValue<List<InvitationResponse>>.data(
            <InvitationResponse>[],
          );

    final query = _buildQuery(organization);
    _query = query;
    final actionError = _actionError;

    // Read through `value` rather than Riverpod 3's removed `valueOrNull`.
    //
    // A screen whose invitations are still in flight shows nothing there rather
    // than an empty table that flickers into a populated one, which is also
    // what `UserList.tsx:223` does — it gates the section on
    // `invitations.length > 0`, and an empty array while loading satisfies that
    // as quietly as a real one. A **failure** does show, because a user with
    // invitations they cannot see has no way to know they are there.
    final loadedInvitations = invitations.value;
    final showInvitations =
        (loadedInvitations != null && loadedInvitations.isNotEmpty) ||
        invitations.hasError;

    return Scaffold(
      body: PagedScrollView(
        onLoadMore: () =>
            ref.read(userPageProvider(_query!).notifier).loadMore(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListScreenHeader(
              title: 'User Management',
              action: canManage
                  ? FilledButton.icon(
                      onPressed: () => context.go(AppRoutes.userCreate),
                      icon: const Icon(Icons.add),
                      label: const Text('Create User'),
                    )
                  : null,
            ),
            const SizedBox(height: 24),
            // `UserList.tsx:224-232`. Above the users, as in the original.
            if (showInvitations) ...[
              Text(
                'Unused Invitations',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              _InvitationSection(
                invitations: invitations,
                columns: _invitationColumns(),
                onDelete: _confirmDeleteInvitation,
              ),
              const SizedBox(height: 32),
            ],
            Text('Users', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            // The debounce from task 4.10, shared with every other list screen
            // — see `DebouncedSearchField` for why.
            DebouncedSearchField(
              hintText: 'Search by username, email, or name...',
              onChanged: (value) => setState(() => _searchTerm = value),
            ),
            const SizedBox(height: 16),
            if (actionError != null) ...[
              ErrorDisplay.fromException(actionError),
              const SizedBox(height: 16),
            ],
            PagedListSection<UserResponse>(
              provider: userPageProvider(query),
              loadMore: () =>
                  ref.read(userPageProvider(query).notifier).loadMore(),
              columns: _userColumns(canViewGlobal: canViewGlobal),
              idOf: (user) => user.userId,
              emptyMessage: 'No users found.',
              // Only reaches the footer, to word its count. Same test as the one
              // `_buildQuery` uses to decide whether to send `search` at all, so
              // the label cannot claim a filter the request did not apply.
              filtered: _searchTerm.isNotEmpty,
              sortBy: _sortBy,
              sortOrder: _sortOrder,
              onSort: _onSort,
              actions: canManage
                  ? (context, user) => [
                      ListRowAction(
                        icon: Icons.edit,
                        label: 'Edit',
                        onPressed: () =>
                            context.go(AppRoutes.userEditPath(user.userId)),
                      ),
                      ListRowAction(
                        icon: Icons.delete,
                        label: 'Delete',
                        isDestructive: true,
                        onPressed: () => _confirmDeleteUser(user),
                      ),
                    ]
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// The invitations table, with its own loading and error states.
///
/// `UserList.tsx:226-231` hands the invitation list to the same `TableView` as
/// the users, with the same shared `error`. Split out here so a failure to
/// load invitations cannot blank the users table below it, and so the delete's
/// consequence — refetching *this* list — reads as belonging to it.
class _InvitationSection extends StatelessWidget {
  const _InvitationSection({
    required this.invitations,
    required this.columns,
    required this.onDelete,
  });

  final AsyncValue<List<InvitationResponse>> invitations;
  final List<ListColumn<InvitationResponse>> columns;
  final Future<void> Function(InvitationResponse) onDelete;

  @override
  Widget build(BuildContext context) => invitations.when(
    loading: () => const Center(child: CircularProgressIndicator()),
    error: (error, _) => ErrorDisplay.fromException(
      error is ApiException ? error : ApiRequestException('$error'),
    ),
    data: (list) => ResponsiveListView<InvitationResponse>(
      data: list,
      columns: columns,
      idOf: (invitation) => invitation.invitationId,
      emptyMessage: 'No unused invitations.',
      actions: (context, invitation) => [
        ListRowAction(
          icon: Icons.delete,
          label: 'Delete',
          isDestructive: true,
          onPressed: () => onDelete(invitation),
        ),
      ],
    ),
  );
}

/// The "Link" cell: a copy button and the URL beside it.
///
/// `UserList.tsx:170-183`. The URL is truncated at 150px with
/// `text-truncate` in the original; a [Flexible] does the same job without
/// pinning a pixel width into a column that also has to survive a card layout
/// at mobile.
class _InvitationLinkCell extends StatelessWidget {
  const _InvitationLinkCell({
    required this.invitation,
    required this.copied,
    required this.onCopy,
  });

  final InvitationResponse invitation;
  final bool copied;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      OutlinedButton(
        onPressed: onCopy,
        child: Text(copied ? 'Copied!' : 'Copy Link'),
      ),
      const SizedBox(width: 8),
      Flexible(
        child: Text(
          invitationUrl(invitation.token),
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: Theme.of(context).colorScheme.outline),
        ),
      ),
    ],
  );
}

/// The link an invitee opens: the app's own origin plus `/register?token=`.
///
/// `UserList.tsx:157,179` writes this twice, from `window.location.origin`.
/// One function so the copy button and the displayed text cannot disagree —
/// which is the same defect class as the bare-string responses in task 10.10,
/// two values that are supposed to be one.
///
/// `Uri.base` rather than `window.location.origin` (task 5.10): it is the
/// document's address on web and the running app's elsewhere, so the same
/// expression is right on both platforms and needs no conditional import.
///
/// **The origin is read defensively, and that is not defensive programming for
/// its own sake.** `Uri.base.origin` throws a [StateError] for any scheme other
/// than http and https, so the obvious one-liner takes the whole screen down
/// with it — under a native URL scheme, and under `flutter test`, where
/// `Uri.base` is a `file:` URL. It was written that way first and every
/// invitation test failed with `Bad state: Origin is only applicable schemes
/// http and https`, which is the same crash a native build would produce the
/// first time someone opened `/users` on a device.
String invitationUrl(String token) =>
    '${_appOrigin()}${AppRoutes.register}?token=$token';

/// The app's own origin, or an empty string when there isn't a usable one.
///
/// An invitee opens this link in a **browser**, so a scheme no browser
/// understands is worth nothing to them — an empty origin yields a relative
/// `/register?token=…`, which is at least a link they can resolve against
/// whatever page they are on, rather than a crash on the screen listing their
/// colleagues' invitations.
String _appOrigin() {
  final base = Uri.base;
  if (base.scheme == 'http' || base.scheme == 'https') return base.origin;
  if (base.hasAuthority) return '${base.scheme}://${base.authority}';
  return '';
}

/// Formats a timezone-naive server timestamp as a date.
///
/// `UserList.tsx:184` calls `new Date(expiresAt).toLocaleDateString()`, which
/// is locale-dependent by design; this keeps the ISO `YYYY-MM-DD` prefix that
/// the server sends (`InvitationRoutes.kt`), which is what a reader of an
/// expiry date actually wants, and returns the raw string if it is not a date
/// at all — the same "never silently blank" rule as the rest of the port.
String formatDate(String timestamp) {
  final parsed = DateTime.tryParse(timestamp);
  if (parsed == null) return timestamp;

  final month = parsed.month.toString().padLeft(2, '0');
  final day = parsed.day.toString().padLeft(2, '0');
  return '${parsed.year}-$month-$day';
}
