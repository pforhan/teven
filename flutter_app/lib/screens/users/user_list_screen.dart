import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/services/list_query.dart';
import '../../core/util/local_date.dart';
import '../../models/invitation.dart';
import '../../models/permissions.dart';
import '../../models/user.dart';
import '../../providers/auth_controller.dart';
import '../../providers/effective_organization_scope.dart';
import '../../providers/service_providers.dart';
import '../../providers/time_zone_controller.dart';
import '../../providers/user_list.dart';
import '../../routing/app_router.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/create_invitation_form.dart';
import '../../widgets/debounced_search_field.dart';
import '../../widgets/error_display.dart';
import '../../widgets/list_screen_header.dart';
import '../../widgets/paged_list_view.dart';
import '../../widgets/record_link_button.dart';
import '../../widgets/responsive_list_view.dart';

/// The user list.
///
/// The original screen was the largest of the four list screens, and the only
/// one that rendered **two** tables: unused invitations above the users, both
/// inside one route. That is why this screen is not a copy of the customer one
/// with different columns.
///
/// Four things here are worth knowing before reading the code:
///
/// - **The two deletes do different things, and only one of them works.** The
/// original user delete called an endpoint that does not exist; the invitation
/// delete is real. Both go through the shared [confirmDestructiveAction], and
/// both refetch rather than navigate away — the *consequence* of a delete stays
/// at the call site, which is the whole reason the dialog is shared. These are
/// the fifth and sixth wired destructive flows; the last two arrived with the
/// event list and event details, so all six are now wired.
/// - **The organization column is conditional.** The original screen added it
/// only for a caller holding `VIEW_USERS_GLOBAL`. An organization-scoped admin
/// sees users in their own organization already, so the column would be four
/// identical values — which is also why [userPageProvider] scopes the query to
/// the selected organization for exactly that caller.
/// - **"Create Invitation" is in place here.** The original toggled an inline
/// invitation form with no dedicated route, so this screen renders it in place
/// as well.
/// - **The invite link is built from `Uri.base`,** not from
/// `window.location.origin` as the original did. Doing it here means the link
/// this screen hands a user is correct on every platform from the start.
class UserListScreen extends ConsumerStatefulWidget {
  const UserListScreen({super.key});

  @override
  ConsumerState<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends ConsumerState<UserListScreen> {
  /// How long the "Copied!" label stays up. The original screen reset the label
  /// after 2000ms.
  static const Duration _copiedIndicatorDuration = Duration(seconds: 2);

  String _searchTerm = '';

  bool _showInvitationForm = false;

  /// The original list opened sorted by username ascending, which is one of the
  /// three columns `UserDao` actually honours.
  String _sortBy = 'username';
  SortOrder _sortOrder = SortOrder.asc;

  /// Status filter for users who can view or manage deactivated accounts.
  String _statusFilter = 'active';

  /// The invitation whose link was last copied, or null. Mirrors the original
  /// screen's copied-invitation state.
  int? _copiedInvitationId;

  Timer? _copiedTimer;

  /// An error from a mutation (deactivate/restore/invitation delete).
  ApiException? _actionError;

  /// The query built during the last build, kept so mutation handlers can
  /// reload the same provider the screen is watching.
  ListQuery? _query;

  @override
  void dispose() {
    // A pending reset would fire into a disposed state, exactly as the search
    // field's debounce would.
    _copiedTimer?.cancel();
    super.dispose();
  }

  /// Matches the original list: re-tapping the active column reverses it, and a
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

  /// Deactivates (soft-deletes) a user.
  Future<void> _confirmDeactivateUser(UserResponse user) async {
    final confirmed = await confirmDestructiveAction(
      context,
      title: 'Deactivate user',
      message:
          'Are you sure you want to deactivate ${user.username}? They will no '
          'longer be able to log in, but their history will be retained and '
          'they can be restored later.',
      confirmLabel: 'Deactivate',
    );

    if (!confirmed || !mounted) return;

    try {
      await ref.read(userServiceProvider).deleteUser(user.userId);
      await ref.read(userPageProvider(_query!).notifier).reload();
      setState(() => _actionError = null);
    } on ApiException catch (error) {
      if (mounted) setState(() => _actionError = error);
    }
  }

  Future<void> _restoreUser(UserResponse user) async {
    try {
      await ref.read(userServiceProvider).restoreUser(user.userId);
      await ref.read(userPageProvider(_query!).notifier).reload();
      setState(() => _actionError = null);
    } on ApiException catch (error) {
      if (mounted) setState(() => _actionError = error);
    }
  }

  /// The invitation delete.
  ///
  /// Refetches the invitations rather than the users: this deletes a different
  /// collection from the one the row sits in, and the two lists are independent
  /// fetches, so the consequence stays at the call site.
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
      // `fetchInvitations` in the original.
      ref.invalidate(unusedInvitationsProvider);
      setState(() => _actionError = null);
    } on ApiException catch (error) {
      if (mounted) setState(() => _actionError = error);
    }
  }

  /// Copies an invite link to the clipboard.
  ///
  /// The origin comes from [Uri.base] rather than `window.location.origin`.
  /// `Uri.base` is the document's own address on web and the running app's
  /// elsewhere, so one expression is right on both, and an invitee always
  /// receives a link they can open in a browser.
  Future<void> _copyInvitationLink(InvitationResponse invitation) async {
    final url = invitationUrl(invitation.token);

    // The original logged a copy failure to the console and said nothing. A
    // user watching a button that visibly does nothing is worse than being told
    // why, so the failure goes to the same banner as a failed delete.
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

  /// The user columns.
  ///
  /// Three of the five are sortable, and those three are exactly the ones
  /// `UserDao.getUsers` switches on (`username`, `displayName`, `email`) —
  /// verified for Roles and organization are not sortable because
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
    required bool showStatus,
  }) => [
    ListColumn<UserResponse>(
      key: 'username',
      label: 'Username',
      sortable: true,
      flex: 2,
      render: (context, user) => RecordLinkButton(
        label: user.username,
        onPressed: () => context.go(AppRoutes.userDetailsPath(user.userId)),
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
    ListColumn<UserResponse>(
      key: 'roles',
      label: 'Roles',
      flex: 1,
      text: (user) => user.roles.join(', '),
    ),
    if (showStatus)
      ListColumn<UserResponse>(
        key: 'status',
        label: 'Status',
        flex: 1,
        text: (user) => user.deletedAt == null ? 'Active' : 'Deactivated',
      ),
    if (canViewGlobal)
      ListColumn<UserResponse>(
        key: 'organization',
        label: 'Organization',
        flex: 4,
        render: (context, user) => RecordLinkButton(
          label: user.organization.name,
          onPressed: () => context.go(
            AppRoutes.organizationDetailsPath(user.organization.organizationId),
          ),
        ),
      ),
  ];

  /// The invitation columns.
  ///
  /// None are sortable — [ResponsiveListView] only renders a sort control on a
  /// column marked `sortable`, and none of these are. The original table also had
  /// a hand-rolled "Actions" column holding a labelled delete button; the action
  /// list here replaces it, which is what the other three screens did.
  /// Builds the provider key from this screen's own state.
  ListQuery _buildQuery(
    int? organizationId, {
    required bool canAccessDeactivated,
  }) => ListQuery(
    search: _searchTerm.isEmpty ? null : _searchTerm,
    sortBy: _sortBy,
    sortOrder: _sortOrder,
    // Scoped by the effective organization: a superadmin in "All
    // Organizations" sees every organization, a superadmin with a selection
    // sees that one, and everyone else sees their own.
    organizationId: organizationId,
    status: canAccessDeactivated ? _statusFilter : null,
  );

  /// The invitation columns.
  List<ListColumn<InvitationResponse>> _invitationColumns(String readerZone) =>
      [
        ListColumn<InvitationResponse>(
          key: 'roleName',
          label: 'Role',
          text: (invitation) => invitation.roleName,
        ),
        // The original screen rendered a null note as `N/A`, so it is shown as
        // text rather than as an empty cell.
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
          text: (invitation) =>
              formatInstantDate(invitation.expiresAt, readerZone),
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final gate = ref.watch(permissionGateProvider);
    // Wider than any other list screen's gate: either scope can manage users,
    // matching the original router's OR-semantics on the create route.
    final canManage = gate.hasAny([
      Permission.manageUsersGlobal,
      Permission.manageUsersOrganization,
    ]);
    final canViewGlobal = gate.has(Permission.viewUsersGlobal);
    final canAccessDeactivated = canViewGlobal || canManage;
    final organizationId = ref.watch(queryOrganizationIdProvider);

    // The original screen fetched invitations only for a manager and rendered
    // the table only when there was something in it. Gating the watch rather
    // than the fetch keeps an unauthorized caller from issuing a request that
    // would 403.
    final invitations = canManage
        ? ref.watch(unusedInvitationsProvider)
        : const AsyncValue<List<InvitationResponse>>.data(
            <InvitationResponse>[],
          );

    final query = _buildQuery(
      organizationId,
      canAccessDeactivated: canAccessDeactivated,
    );
    _query = query;
    final actionError = _actionError;

    // Read through `value` rather than Riverpod 3's removed `valueOrNull`.
    //
    // A screen whose invitations are still in flight shows nothing there rather
    // than an empty table that flickers into a populated one, which is also what
    // the original screen did — it gated the section on a non-empty list, and an
    // empty array while loading satisfied that as quietly as a real one. A
    // **failure** does show, because a user with invitations they cannot see has
    // no way to know they are there.
    final loadedInvitations = invitations.value;
    final showInvitations =
        (loadedInvitations != null && loadedInvitations.isNotEmpty) ||
        invitations.hasError;

    Future<void> onRefresh() async {
      if (_query != null) {
        await ref.read(userPageProvider(_query!).notifier).reload();
      }
      ref.invalidate(unusedInvitationsProvider);
    }

    return Scaffold(
      body: PagedScrollView(
        onLoadMore: () =>
            ref.read(userPageProvider(_query!).notifier).loadMore(),
        onRefresh: onRefresh,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListScreenHeader(
              title: 'User Management',
              action: canManage
                  ? Wrap(
                      spacing: 8,
                      children: [
                        FilledButton.icon(
                          onPressed: () => context.go(AppRoutes.userCreate),
                          icon: const Icon(Icons.add),
                          label: const Text('Create User'),
                        ),
                        FilledButton.icon(
                          onPressed: () =>
                              setState(() => _showInvitationForm = true),
                          icon: const Icon(Icons.mail),
                          label: const Text('Create Invitation'),
                        ),
                      ],
                    )
                  : null,
            ),
            if (canManage && _showInvitationForm) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLowest,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: CreateInvitationForm(
                  onInvitationCreated: (_) {
                    setState(() => _showInvitationForm = false);
                    ref.invalidate(unusedInvitationsProvider);
                  },
                  onCancel: () => setState(() => _showInvitationForm = false),
                ),
              ),
            ],
            const SizedBox(height: 24),
            // Above the users, as in the original screen.
            if (showInvitations) ...[
              Text(
                'Unused Invitations',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              _InvitationSection(
                invitations: invitations,
                columns: _invitationColumns(
                  ref.watch(timeZoneControllerProvider).value?.effectiveZone ??
                      'UTC',
                ),
                onDelete: _confirmDeleteInvitation,
              ),
              const SizedBox(height: 32),
            ],
            Text('Users', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            if (canAccessDeactivated) ...[
              SegmentedButton<String>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: 'active', label: Text('Active')),
                  ButtonSegment(
                    value: 'deactivated',
                    label: Text('Deactivated'),
                  ),
                  ButtonSegment(value: 'all', label: Text('All')),
                ],
                selected: {_statusFilter},
                onSelectionChanged: (selection) {
                  setState(() => _statusFilter = selection.first);
                },
              ),
              const SizedBox(height: 16),
            ],
            // The debounce from shared with every other list screen
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
              columns: _userColumns(
                canViewGlobal: canViewGlobal,
                showStatus: canAccessDeactivated,
              ),
              idOf: (user) => user.userId,
              emptyMessage: 'No users found.',
              filtered: _searchTerm.isNotEmpty,
              sortBy: _sortBy,
              sortOrder: _sortOrder,
              onSort: _onSort,
              actions: canManage
                  ? (context, user) {
                      final isDeactivated = user.deletedAt != null;
                      return [
                        if (!isDeactivated)
                          ListRowAction(
                            icon: Icons.edit,
                            label: 'Edit',
                            onPressed: () =>
                                context.go(AppRoutes.userEditPath(user.userId)),
                          ),
                        if (!isDeactivated)
                          ListRowAction(
                            icon: Icons.person_off,
                            label: 'Deactivate',
                            isDestructive: true,
                            onPressed: () => _confirmDeactivateUser(user),
                          ),
                        if (isDeactivated && canManage)
                          ListRowAction(
                            icon: Icons.restore,
                            label: 'Restore',
                            onPressed: () => _restoreUser(user),
                          ),
                      ];
                    }
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
/// The original screen handed the invitation list to the same table component as
/// the users, with the same shared error. Split out here so a failure to load
/// invitations cannot blank the users table below it, and so the delete's
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
/// The URL is ellipsized rather than given a fixed pixel width, so it fits the
/// column on a wide table and the card layout on mobile without pinning a size
/// that only made sense on a desktop.
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
/// The original screen built this twice from `window.location.origin`. One
/// function so the copy button and the displayed text cannot disagree — two
/// values that are supposed to be one.
///
/// `Uri.base` rather than `window.location.origin` it is the
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
///
/// The token is interpolated, not percent-encoded. `InvitationRoutes` mints
/// `UUID.randomUUID`, which is `[0-9a-f-]` and needs no encoding, and
/// `Uri(queryParameters:...)` would encode the separator-free token
/// identically — so the readable form is kept and the constraint is recorded
/// here rather than the other way round.
/// [base] exists so the origin branches can be tested at all, and defaults to
/// [Uri.base]. **`flutter test` runs against a `file:` URI**, so every widget
/// test in this repo sees the empty-origin branch and nothing has ever executed
/// the `http`/`https` one — which is the branch that runs in production and the
/// branch this screen was actually ported from. It is a parameter rather than a
/// private helper so a test can hold the production function to its real
/// contract rather than to a copy of it.
String invitationUrl(String token, {Uri? base}) =>
    '${_appOrigin(base ?? Uri.base)}${AppRoutes.register}?token=$token';

/// The app's own origin, or an empty string when there isn't a usable one.
///
/// An invitee opens this link in a **browser**, so a scheme no browser
/// understands is worth nothing to them — an empty origin yields a relative
/// `/register?token=…`, which is at least a link they can resolve against
/// whatever page they are on, rather than a crash on the screen listing their
/// colleagues' invitations.
///
/// **The path is dropped, and that is a real decision rather than a detail of
/// `origin`.** On web [Uri.base] is the whole document URL, so a user sitting
/// on `/users` would otherwise email their colleagues a link to
/// `/users/register` — which the SPA fallback would serve, and which the
/// original router would then redirect away from, losing the token. The original
/// got this right by accident: `window.location.origin` has no path to keep.
String _appOrigin(Uri base) {
  if (base.scheme == 'http' || base.scheme == 'https') return base.origin;
  // **`base.authority.isNotEmpty`, not `base.hasAuthority`, and the difference
  // is a real link.** `file:///srv/teven` has a *present but empty* authority,
  // so `hasAuthority` is true and the naive guard produces the origin
  // `"file://"` — which yields `file:///register?token=…`, a URL that no
  // browser will open and that no invitee can be shown. The empty origin gives
  // `/register?token=…` instead, which is the degradation the doc comment above
  // promises. `flutter test` runs against exactly such a `file:` URI, so every
  // widget test in this repo was asserting against the worse of the two.
  if (base.authority.isNotEmpty) return '${base.scheme}://${base.authority}';
  return '';
}
