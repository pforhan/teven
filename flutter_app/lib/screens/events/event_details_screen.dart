import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/api_exception.dart';
import '../../core/layout/breakpoints.dart';
import '../../core/theme/teven_theme.dart';
import '../../models/customer.dart';
import '../../models/event.dart';
import '../../models/permissions.dart';
import '../../providers/auth_controller.dart';
import '../../providers/service_providers.dart';
import '../../routing/app_router.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/error_display.dart';
import '../../widgets/other_events_panel.dart';

/// One event, in full — task 7.6.
///
/// `EventDetails.tsx` (277 lines). The title, the date, the time, the
/// location, the description, the customer, the inventory; and in the
/// sidebar, the other events on the same day, this user's own availability,
/// and the staff roster.
///
/// **Two things about the React original are worth stating before the code.**
///
/// The first is that **it never shows an error when the event fails to load.**
/// `EventDetails.tsx:80` returns a spinner whenever `event` is null, and the
/// `catch` at `:31` only sets `error` — which is rendered at `:133`, *inside*
/// the card that the spinner's early return never reaches. So a 404, a 403
/// or a dead backend produce an endless spinner and a message nobody can
/// read. This port shows the error instead, which is what every other screen
/// in the port does (see the event list's `ErrorDisplay`) and the only thing
/// that can be done about a failure that is not going to fix itself.
///
/// The second is that **the delete navigates away rather than refetching.**
/// `EventDetails.tsx:49` calls `navigate('/events')` after a successful
/// delete, and the screen it came from does not exist any more — so
/// refetching would be fetching a record that is gone. This is the one case
/// where *not* refetching is the point, and it is why the shared delete
/// dialog (task 4.8) leaves the consequence at the call site.
class EventDetailsScreen extends ConsumerStatefulWidget {
  const EventDetailsScreen({super.key, required this.eventId});

  final int eventId;

  @override
  ConsumerState<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends ConsumerState<EventDetailsScreen> {
  /// The event, once it has loaded.
  EventResponse? _event;

  /// The first load is in flight.
  ///
  /// **Only the first load.** A refetch — the one after an RSVP — leaves the
  /// event on screen, because taking it away and putting a spinner in its
  /// place is the flash task 4.14 was filed to remove. The React original
  /// does the same: its `fetchEvent` sets `event` and never clears it.
  bool _loading = true;

  /// The load failed.
  ApiException? _loadError;

  /// A delete or an RSVP failed.
  ///
  /// Separate from [_loadError] because they are shown in different places:
  /// the load error replaces the body, and the action error sits under the
  /// event's title, where `EventDetails.tsx:133` puts it.
  ApiException? _actionError;

  /// The confirmation that an RSVP landed.
  String? _successMessage;

  /// This user's own answer, or null when they have not answered.
  ///
  /// **Kept separately from the event's RSVP list** because the React
  /// original keeps it separately too (`EventDetails.tsx:16`), and because it
  /// is set the moment a request succeeds — before the refetch that follows
  /// it lands. The button states would otherwise lag behind the click by a
  /// round trip.
  String? _myRsvpStatus;

  /// A delete or an RSVP is in flight.
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load(initial: true));
  }

  /// Fetches the event.
  ///
  /// [initial] distinguishes the first load — which shows a spinner and owns
  /// the error state — from the refetch after an RSVP, which does neither.
  Future<void> _load({required bool initial}) async {
    if (initial && mounted) {
      setState(() => _loading = true);
    }
    try {
      final event = await ref
          .read(eventServiceProvider)
          .getEvent(widget.eventId);
      if (!mounted) return;
      setState(() {
        _event = event;
        _myRsvpStatus = _statusOf(event);
        _loadError = null;
        if (initial) _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        if (initial) {
          _loadError = error;
          _loading = false;
        } else {
          _actionError = error;
        }
      });
    }
  }

  /// This user's own availability on [event], or null when they have none.
  ///
  /// `EventDetails.tsx:29` finds it among the event's RSVPs by user id
  /// rather than reading a denormalized field — the server sends no "your
  /// answer" on the event — and `|| null` turns an empty availability into
  /// "no answer".
  String? _statusOf(EventResponse event) {
    final userId = ref.read(userContextProvider)?.user.userId;
    if (userId == null) return null;
    for (final rsvp in event.rsvps) {
      if (rsvp.userId == userId) {
        return rsvp.availability.isEmpty ? null : rsvp.availability;
      }
    }
    return null;
  }

  /// Posts this user's availability.
  ///
  /// `EventDetails.tsx:60`. The availability is a **free-form string** — the
  /// server type is `String` with no validation (`RsvpRequest.kt`) — and the
  /// three the app posts are named in [RsvpAvailability] plus `'no response'`,
  /// which is the original's own literal for "clear my answer".
  ///
  /// **The event is refetched afterwards,** which is what the original does
  /// and the only way the roster repaints: the server answers `success("OK")`,
  /// so nothing comes back to display, and the new availability has to come
  /// from a fresh `GET /api/events/{id}`.
  Future<void> _rsvp(String availability) async {
    if (_submitting) return;
    setState(() {
      _actionError = null;
      _successMessage = null;
      _submitting = true;
    });
    try {
      await ref
          .read(eventServiceProvider)
          .rsvpToEvent(widget.eventId, RsvpRequest(availability: availability));
      if (!mounted) return;
      setState(() {
        _successMessage = 'Successfully updated RSVP to $availability!';
        _myRsvpStatus = availability;
        _submitting = false;
      });
      await _load(initial: false);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _actionError = error;
        _submitting = false;
      });
    }
  }

  /// Deletes the event and leaves.
  ///
  /// `EventDetails.tsx:44`. The **sixth and last** of the React app's
  /// `window.confirm` delete flows, and the only one whose consequence is a
  /// navigation rather than a refetch — see the class comment.
  Future<void> _confirmDelete() async {
    final event = _event;
    if (event == null) return;

    final confirmed = await confirmDestructiveAction(
      context,
      title: 'Delete event',
      message:
          'Are you sure you want to delete "${event.title}"? This cannot be '
          'undone.',
    );
    if (!confirmed || !mounted) return;

    setState(() {
      _actionError = null;
      _submitting = true;
    });
    try {
      await ref.read(eventServiceProvider).deleteEvent(widget.eventId);
      if (!mounted) return;
      // **Away, not a refetch.** The record is gone; there is nothing left to
      // fetch. `EventDetails.tsx:49` navigates to the events list, and so
      // does this.
      context.go(AppRoutes.events);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _actionError = error;
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final gate = ref.watch(permissionGateProvider);
    final canManage = gate.has(Permission.manageEventsOrganization);
    final canJoin = gate.has(Permission.assignToEventsSelf);

    final event = _event;

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(
              canManage: canManage,
              submitting: _submitting,
              onEdit: () => context.go(AppRoutes.eventEditPath(widget.eventId)),
              onDelete: () => unawaited(_confirmDelete()),
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (event == null)
              // **The divergence.** The React original spins here forever; see
              // the class comment.
              ErrorDisplay.fromException(
                _loadError ??
                    const ApiRequestException('That event could not be found.'),
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final main = _EventCard(
                    event: event,
                    actionError: _actionError,
                    successMessage: _successMessage,
                  );
                  final side = _Sidebar(
                    event: event,
                    canJoin: canJoin,
                    canManage: canManage,
                    myRsvpStatus: _myRsvpStatus,
                    submitting: _submitting,
                    onRsvp: (availability) => unawaited(_rsvp(availability)),
                  );

                  // **`col-lg-8` / `col-lg-4`, one column below.**
                  //
                  // **The threshold is the content width, not the window's**,
                  // and the difference is not cosmetic. Bootstrap's `lg` is
                  // 992px of *viewport*; the React original has a navbar
                  // across the top, so its content *is* its viewport. This
                  // port has a rail down the side, which takes 80px on a
                  // tablet layout and 256px on a desktop one — so a viewport
                  // of 1100px leaves about 820px of column, and a split
                  // keyed on the window would put a 330px sidebar into a
                  // 820px space.
                  //
                  // 860 is the width at which a 2:1 split gives the sidebar
                  // about 280px and the main card about 560px. Below it the
                  // sidebar stacks under the card instead — and the thing
                  // that decides it is the width of the *card*, not of the
                  // window.
                  if (constraints.maxWidth < kTwoColumnContentWidth) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [main, const SizedBox(height: 16), side],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 8 of 12 and 4 of 12.
                      Expanded(flex: 2, child: main),
                      const SizedBox(width: 16),
                      Expanded(flex: 1, child: side),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

/// The back button, and the edit and delete pair.
///
/// `EventDetails.tsx:96-106`: a `d-flex justify-content-between` with the
/// back button on the left and — for a manager — an edit and a delete button
/// on the right.
class _Header extends StatelessWidget {
  const _Header({
    required this.canManage,
    required this.submitting,
    required this.onEdit,
    required this.onDelete,
  });

  final bool canManage;
  final bool submitting;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.spaceBetween,
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: 8,
    runSpacing: 8,
    children: [
      OutlinedButton.icon(
        onPressed: () => context.go(AppRoutes.events),
        icon: const Icon(Icons.arrow_back),
        label: const Text('Back to Events'),
      ),
      // **The buttons are absent, not disabled,** for a user who may not
      // manage events. The React original renders the group only when the
      // permission is held.
      if (canManage)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.primary,
              ),
              onPressed: submitting ? null : onEdit,
              child: const Text('Edit'),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: submitting ? null : onDelete,
              child: const Text('Delete'),
            ),
          ],
        ),
    ],
  );
}

/// The main card: the event itself.
class _EventCard extends StatelessWidget {
  const _EventCard({
    required this.event,
    required this.actionError,
    required this.successMessage,
  });

  final EventResponse event;
  final ApiException? actionError;
  final String? successMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final description = event.description;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              event.title,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _MetaRow(event: event),
            // **The banners sit here,** where `EventDetails.tsx:133` puts
            // them: under the title, above the description.
            if (actionError != null) ...[
              const SizedBox(height: 16),
              ErrorDisplay.fromException(actionError!),
            ],
            if (successMessage != null) ...[
              const SizedBox(height: 16),
              _SuccessBanner(message: successMessage!),
            ],
            if (description != null && description.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Notes / Description',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              // **`whiteSpace: pre-wrap`** in the original: the line breaks in
              // a description are the author's, and a single paragraph of
              // joined-up lines is a different document. Flutter's `Text`
              // keeps the newlines.
              Text(description, style: theme.textTheme.bodyLarge),
            ],
            if (event.customer != null) ...[
              const SizedBox(height: 16),
              _CustomerCard(customer: event.customer!),
            ],
            if (event.inventoryItems.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Inventory Required',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              _InventoryGrid(items: event.inventoryItems),
            ],
          ],
        ),
      ),
    );
  }
}

/// The date, the time, and the location.
///
/// `EventDetails.tsx:114-129`: a `d-flex gap-3` of three spans, each with an
/// icon in front of it.
class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.event});

  final EventResponse event;

  @override
  Widget build(BuildContext context) {
    final location = event.location;

    return LayoutBuilder(
      builder: (context, constraints) => Wrap(
        spacing: 16,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _MetaItem(icon: Icons.event_note, text: event.date),
          _MetaItem(
            icon: Icons.schedule,
            // **The raw wire time**, and the duration in minutes — as the
            // original renders it.
            text: '${event.time} (${event.durationMinutes} min)',
          ),
          if (location != null && location.isNotEmpty)
            _LocationLink(location: location, maxWidth: constraints.maxWidth),
        ],
      ),
    );
  }
}

/// An icon and its text.
class _MetaItem extends StatelessWidget {
  const _MetaItem({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.secondary),
        const SizedBox(width: 8),
        Text(text, style: theme.textTheme.bodyMedium),
      ],
    );
  }
}

/// The location, linking to Google Maps.
///
/// `EventDetails.tsx:120-127` renders it as an `<a>` to
/// `https://www.google.com/maps/search/?api=1&query={location}`.
///
/// **The link opens in a new tab,** as the original's `target="_blank"` does.
/// `url_launcher` is the one package this screen adds, and the reason is
/// here: a location that cannot be opened is a location that cannot be found,
/// and there is no way to open a URL from Flutter without one.
///
/// **The address wraps** rather than overflowing, which needs the width to be
/// bounded — a `Wrap` hands its children unbounded width, so the constraint
/// comes from the card's own layout.
class _LocationLink extends StatelessWidget {
  const _LocationLink({required this.location, required this.maxWidth});

  final String location;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query='
      '${Uri.encodeComponent(location)}',
    );

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.place_outlined,
            size: 16,
            color: theme.colorScheme.secondary,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: TextButton(
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.primary,
                padding: EdgeInsets.zero,
                minimumSize: const Size(48, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () => unawaited(_open(uri)),
              child: Text(
                location,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _open(Uri uri) async {
    // A failure here is not worth a banner: the browser refused to open a
    // link the user asked for, and the address is on screen either way.
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

/// The green confirmation.
class _SuccessBanner extends StatelessWidget {
  const _SuccessBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: TevenTheme.successSurface,
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      message,
      style: const TextStyle(color: TevenTheme.onSuccessSurface),
    ),
  );
}

/// The customer the event is for.
///
/// `EventDetails.tsx:143-150`: a `bg-light` box with a thick primary border
/// down its left edge.
class _CustomerCard extends StatelessWidget {
  const _CustomerCard({required this.customer});

  final CustomerResponse customer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // **Empty rather than null.** The React original tests `event.customer.phone
    // &&`, which is falsy for an empty string; the port's model types both as
    // a non-nullable `String` that defaults to `''`, so the equivalent test
    // is emptiness.
    final phone = customer.phone;
    final address = customer.address;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        // **`bg-light`**, which on a white card is a pale grey. The port's
        // cards are the page's own colour, so the callout takes the next
        // shade up — the point of it is that it is a separate block.
        color: theme.colorScheme.outlineVariant,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(4),
          bottomLeft: Radius.circular(4),
          topRight: Radius.circular(4),
          bottomRight: Radius.circular(4),
        ),
        // **`border-start border-4 border-primary`** — a four-pixel primary
        // stripe down the left edge.
        border: const Border(
          left: BorderSide(color: TevenTheme.primary, width: 4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CUSTOMER',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.secondary,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(customer.name, style: theme.textTheme.titleMedium),
          if (phone.isNotEmpty) ...[
            const SizedBox(height: 4),
            _CustomerLine(icon: Icons.phone, text: phone),
          ],
          if (address.isNotEmpty)
            _CustomerLine(icon: Icons.home_outlined, text: address),
        ],
      ),
    );
  }
}

/// One line of the customer's details.
class _CustomerLine extends StatelessWidget {
  const _CustomerLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 14, color: theme.colorScheme.secondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.secondary,
            ),
          ),
        ),
      ],
    );
  }
}

/// The inventory the event needs.
///
/// `EventDetails.tsx:152-167`: a `row-cols-1 row-cols-md-2` grid of small
/// cards, each a quantity badge beside the item's name.
class _InventoryGrid extends StatelessWidget {
  const _InventoryGrid({required this.items});

  final List<EventInventoryItem> items;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      // **`row-cols-md-2`** — one column on a phone, two above it. The app's
      // own tablet threshold (700) is used rather than Bootstrap's 768, for
      // the same reason the column split above uses the app's threshold.
      final twoColumns = constraints.maxWidth >= AppBreakpoints.tablet;
      const gap = 12.0;
      final itemWidth = twoColumns
          ? (constraints.maxWidth - gap) / 2
          : constraints.maxWidth;

      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final item in items)
            SizedBox(
              width: itemWidth,
              child: _InventoryTile(item: item),
            ),
        ],
      );
    },
  );
}

/// One inventory line.
class _InventoryTile extends StatelessWidget {
  const _InventoryTile({required this.item});

  final EventInventoryItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.colorScheme.outlineVariant,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          // **`badge bg-secondary rounded-pill`** — the quantity in a grey
          // pill.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.secondary,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '${item.quantity}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              item.itemName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

/// The sidebar: the other events, this user's availability, and the roster.
class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.event,
    required this.canJoin,
    required this.canManage,
    required this.myRsvpStatus,
    required this.submitting,
    required this.onRsvp,
  });

  final EventResponse event;
  final bool canJoin;
  final bool canManage;
  final String? myRsvpStatus;
  final bool submitting;
  final ValueChanged<String> onRsvp;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      // **`EventDetails.tsx:175-181`.** The panel fetches the other events on
      // this event's day, in this event's organization, minus this event.
      OtherEventsPanel(
        date: event.date,
        organizationId: event.organization.organizationId.toString(),
        excludeEventId: event.eventId.toString(),
      ),
      const SizedBox(height: 16),
      _AvailabilityCard(
        canJoin: canJoin,
        myRsvpStatus: myRsvpStatus,
        submitting: submitting,
        onRsvp: onRsvp,
      ),
      const SizedBox(height: 16),
      _RosterCard(event: event, canManage: canManage),
    ],
  );
}

/// "Your Availability" — the two RSVP buttons.
class _AvailabilityCard extends StatelessWidget {
  const _AvailabilityCard({
    required this.canJoin,
    required this.myRsvpStatus,
    required this.submitting,
    required this.onRsvp,
  });

  final bool canJoin;
  final String? myRsvpStatus;
  final bool submitting;
  final ValueChanged<String> onRsvp;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = myRsvpStatus;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Your Availability',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            if (canJoin)
              // **`btn-group w-100`** — the two buttons share the row.
              Row(
                children: [
                  Expanded(
                    child: _AvailabilityButton(
                      label: 'Going',
                      icon: Icons.check_circle_outline,
                      color: TevenTheme.success,
                      selected: status == RsvpAvailability.available,
                      onPressed: submitting
                          ? null
                          : () => onRsvp(RsvpAvailability.available),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _AvailabilityButton(
                      label: 'Not Going',
                      icon: Icons.cancel_outlined,
                      color: TevenTheme.danger,
                      selected: status == RsvpAvailability.unavailable,
                      onPressed: submitting
                          ? null
                          : () => onRsvp(RsvpAvailability.unavailable),
                    ),
                  ),
                ],
              )
            else
              Text(
                "You don't have permission to RSVP to this event.",
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.secondary,
                ),
              ),
            if (status != null) ...[
              const SizedBox(height: 8),
              // **"Clear my response"** — `EventDetails.tsx:206`. It posts
              // `'no response'`, which is **not** one of
              // [RsvpAvailability]'s values and is not a removal: the server
              // stores the string as the availability, so the user stops
              // counting as available or unavailable and the roster's three
              // lists each stop counting them.
              TextButton(
                onPressed: submitting ? null : () => onRsvp(kRsvpCleared),
                child: const Text('Clear my response'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One of the two availability buttons.
///
/// **Filled when it is this user's answer, outlined when it is not** — the
/// original's `btn-success` / `btn-outline-success` pair, and the whole of
/// how it shows which answer is current.
class _AvailabilityButton extends StatelessWidget {
  const _AvailabilityButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    style: OutlinedButton.styleFrom(
      foregroundColor: selected ? Colors.white : color,
      backgroundColor: selected ? color : null,
      side: BorderSide(color: color),
      padding: const EdgeInsets.symmetric(vertical: 12),
    ),
    onPressed: onPressed,
    icon: Icon(icon, size: 18),
    label: Text(label),
  );
}

/// The staff roster: who was invited, who is coming, who declined.
class _RosterCard extends StatelessWidget {
  const _RosterCard({required this.event, required this.canManage});

  final EventResponse event;
  final bool canManage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // `EventDetails.tsx:90-92` splits the roster three ways. **A fourth
    // possibility is not in the split:** a user who answered `'no response'`
    // appears in none of the three lists, because the server stores that
    // string as their availability. That is the original's behaviour and it
    // is kept — see the note on the clear button.
    final invited = event.rsvps
        .where((rsvp) => rsvp.availability == RsvpAvailability.requested)
        .toList();
    final confirmed = event.rsvps
        .where((rsvp) => rsvp.availability == RsvpAvailability.available)
        .toList();
    final declined = event.rsvps
        .where((rsvp) => rsvp.availability == RsvpAvailability.unavailable)
        .toList();

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Staff Roster',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // **`badge bg-primary rounded-pill`** — the number of people
                // who have confirmed.
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${confirmed.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _RosterSection(
              title: 'Invited',
              color: theme.colorScheme.primary,
              icon: Icons.mail_outline,
              members: invited,
              emptyMessage: 'No pending invitations.',
            ),
            const SizedBox(height: 16),
            _RosterSection(
              title: 'Confirmed',
              color: TevenTheme.success,
              icon: Icons.person_outline,
              members: confirmed,
              emptyMessage: 'No one confirmed yet.',
            ),
            // **The declined list is for managers only** —
            // `EventDetails.tsx:256`. A user who cannot manage events does
            // not see who said no.
            if (canManage && declined.isNotEmpty) ...[
              const SizedBox(height: 16),
              _RosterSection(
                title: 'Declined',
                color: TevenTheme.danger,
                icon: Icons.person_off_outlined,
                members: declined,
                emptyMessage: 'Nobody has declined.',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One group on the roster.
class _RosterSection extends StatelessWidget {
  const _RosterSection({
    required this.title,
    required this.color,
    required this.icon,
    required this.members,
    required this.emptyMessage,
  });

  final String title;
  final Color color;
  final IconData icon;
  final List<RsvpStatus> members;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        if (members.isEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Text(
              emptyMessage,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.secondary,
              ),
            ),
          )
        else
          for (final member in members)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Icon(icon, size: 14, color: color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      // **`displayName || email`** — the original falls back
                      // to the address when a user has no display name.
                      member.displayName.isNotEmpty
                          ? member.displayName
                          : member.email,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}

/// The content width at which the details screen splits into two columns.
///
/// **The card's width, not the window's.** The rail takes 80px of the window
/// on a tablet layout and 256px on a desktop one, so the same window size
/// leaves very different amounts of room for the content — and the question
/// the split answers is "is there room for a main card and a sidebar", which
/// is about the content.
///
/// 860 is the width at which a 2:1 split gives the sidebar about 280px and
/// the main card about 560px. Below it the sidebar stacks under the card.
///
/// **The React original splits at a 992px viewport,** which is the same
/// decision made against a different measure: its navbar is across the top,
/// so its content *is* its viewport. See the comment at the split.
const double kTwoColumnContentWidth = 860;

/// What the clear button posts.
///
/// `'no response'`, verbatim from `EventDetails.tsx:208` — and the same
/// literal the event list's clear button posts (`EventListPage.tsx:153`).
/// **Not** `''`, and **not** a member of [RsvpAvailability]: the server
/// stores it as a free-form string, so it is a fourth answer rather than the
/// absence of one. Task 10.17 owns the question of whether that column should
/// hold a closed set.
const String kRsvpCleared = 'no response';
