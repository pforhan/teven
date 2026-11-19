import 'dart:async' show Timer, unawaited;

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
import '../../providers/organization_controller.dart';
import '../../providers/service_providers.dart';
import '../../providers/time_zone_controller.dart';
import '../../routing/app_router.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/error_display.dart';
import '../../widgets/day_events_panel.dart';

/// One event, in full.
///
/// The title, the date, the time, the location, the description, the customer,
/// the inventory; and in the sidebar, the other events on the same day, this
/// user's own availability, and the staff roster.
///
/// **Two things about the original screen are worth stating before the code.**
///
/// The first is that **it never showed an error when the event failed to load.**
/// The original returned a spinner whenever `event` was null, and the catch only
/// set `error` — which was rendered inside the card that the spinner's early
/// return never reached. So a 404, a 403 or a dead backend produced an endless
/// spinner and a message nobody could read. This port shows the error instead,
/// which is what every other screen in the port does (see the event list's
/// `ErrorDisplay`) and the only thing that can be done about a failure that is
/// not going to fix itself.
///
/// The second is that **the delete navigated away rather than refetching.** The
/// original navigated to `/events` after a successful delete, and the screen it
/// came from did not exist any more — so refetching would be fetching a record
/// that is gone. This is the one case where *not* refetching is the point, and
/// it is why the shared delete dialog leaves the consequence at the call site.
class EventDetailsScreen extends ConsumerStatefulWidget {
  const EventDetailsScreen({super.key, required this.eventId, this.backToDay});

  final int eventId;

  /// When set to a `yyyy-MM-dd` date, the back control returns to that day view
  /// and intra-day navigation preserves this context.
  final String? backToDay;

  @override
  ConsumerState<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends ConsumerState<EventDetailsScreen> {
  /// The event, once it has loaded.
  EventResponse? _event;

  /// True while there is no event to show yet.
  bool _loading = true;

  /// A fetch is in flight while an event is already on screen.
  ///
  /// Used to keep the previous event visible when navigating to another event,
  /// instead of flashing a full-screen spinner.
  bool _refreshing = false;

  /// True when a refresh has been in flight for more than 200ms.
  bool _showRefreshingBar = false;
  Timer? _refreshingBarTimer;

  /// The load failed.
  ApiException? _loadError;

  /// A delete or an RSVP failed.
  ///
  /// Separate from [_loadError] because they are shown in different places:
  /// the load error replaces the body, and the action error sits under the
  /// event's title, where the original screen put it.
  ApiException? _actionError;

  /// The confirmation that an RSVP landed.
  String? _successMessage;

  /// This user's own answer, or null when they have not answered.
  ///
  /// **Kept separately from the event's RSVP list** because the original kept it
  /// separately too, and because it is set the moment a request succeeds —
  /// before the refetch that follows it lands. The button states would otherwise
  /// lag behind the click by a round trip.
  String? _myRsvpStatus;

  /// A delete or an RSVP is in flight.
  bool _submitting = false;

  /// Counts loads so a slow response cannot overwrite a newer one.
  ///
  /// Navigating between events reuses this screen with a different
  /// [EventDetailsScreen.eventId] (the "Other events" panel, the day view, and
  /// browser back all do this). Without a guard, an earlier request that
  /// resolves late would repaint the wrong event — the URL would name one event
  /// while the content showed another.
  int _request = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load(initial: _event == null));
  }

  @override
  void dispose() {
    _refreshingBarTimer?.cancel();
    super.dispose();
  }

  void _startRefreshingBarTimer() {
    _refreshingBarTimer?.cancel();
    _refreshingBarTimer = Timer(const Duration(milliseconds: 200), () {
      if (!mounted || !_refreshing) return;
      setState(() => _showRefreshingBar = true);
    });
  }

  void _stopRefreshingBar() {
    _refreshingBarTimer?.cancel();
    _refreshingBarTimer = null;
    _showRefreshingBar = false;
  }

  @override
  void didUpdateWidget(covariant EventDetailsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.eventId != widget.eventId) {
      setState(() {
        _actionError = null;
        _successMessage = null;
        _submitting = false;
        // Keep the previous event visible while the next one loads to avoid a
        // full-screen flash; _load will replace it (or show a load error).
        _refreshing = _event != null;
        _loading = _event == null;
        if (!_refreshing) _stopRefreshingBar();
      });
      if (_refreshing) _startRefreshingBarTimer();
      unawaited(_load(initial: _event == null));
    }
  }

  /// Fetches the event.
  ///
  /// [initial] means there is no event content to keep on screen — show a
  /// spinner and treat failures as load errors. Otherwise keep existing content
  /// visible while refreshing; RSVP refetch failures surface as action errors.
  Future<void> _load({required bool initial}) async {
    final request = ++_request;
    final showAsInitial = initial && _event == null;
    final wasRefreshing = _refreshing;
    if (mounted) {
      setState(() {
        if (showAsInitial) {
          _loading = true;
        } else if (initial) {
          // Navigating to a different event while one is shown.
          _refreshing = true;
        }
      });
    }
    if (initial && !showAsInitial && !wasRefreshing) {
      _startRefreshingBarTimer();
    }
    try {
      final event = await ref
          .read(eventServiceProvider)
          .getEvent(widget.eventId);
      if (!mounted || request != _request) return;
      setState(() {
        _event = event;
        _myRsvpStatus = _statusOf(event);
        _loadError = null;
        _loading = false;
        _refreshing = false;
        _stopRefreshingBar();
      });
    } on ApiException catch (error) {
      if (!mounted || request != _request) return;
      setState(() {
        _refreshing = false;
        _stopRefreshingBar();
        if (showAsInitial) {
          _loadError = error;
          _loading = false;
        } else if (initial) {
          // Failed to load the newly requested event: do not keep showing the
          // previous event under a different URL.
          _event = null;
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
  /// The original found it among the event's RSVPs by user id rather than
  /// reading a denormalized field — the server sends no "your answer" on the
  /// event — and turned an empty availability into "no answer".
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
  /// **The event is refetched afterwards,** because the server response does not
  /// include the updated roster payload.
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
      final label = switch (availability) {
        RsvpAvailability.accepted => 'Going',
        RsvpAvailability.declined => 'Not going',
        RsvpAvailability.tentative => 'Maybe',
        RsvpAvailability.needsAction => 'No response',
        _ => availability,
      };
      setState(() {
        _successMessage = 'Successfully updated RSVP to $label.';
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
  /// The **sixth and last** of the original app's `window.confirm` delete flows,
  /// and the only one whose consequence was a navigation rather than a refetch —
  /// see the class comment.
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
      // fetch. The original navigated to the events list, and so does this.
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
    final readerZone =
        ref.watch(timeZoneControllerProvider).value?.effectiveZone ?? 'UTC';

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
              backToDay: widget.backToDay,
              onEdit: () => context.go(AppRoutes.eventEditPath(widget.eventId)),
              onDelete: () => unawaited(_confirmDelete()),
            ),
            const SizedBox(height: 16),
            if (_loading && event == null)
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
              Stack(
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final main = _EventCard(
                        event: event,
                        readerZone: readerZone,
                        actionError: _actionError,
                        successMessage: _successMessage,
                      );
                      final side = _Sidebar(
                        event: event,
                        readerZone: readerZone,
                        canJoin: canJoin,
                        canManage: canManage,
                        myRsvpStatus: _myRsvpStatus,
                        submitting: _submitting,
                        backToDay: widget.backToDay,
                        onRsvp: (availability) =>
                            unawaited(_rsvp(availability)),
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
                  if (_showRefreshingBar && _refreshing)
                    const Positioned(
                      left: 0,
                      right: 0,
                      top: 0,
                      child: LinearProgressIndicator(minHeight: 2),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// The back button, and the edit and delete pair.
///
/// The original laid this out as a space-between row with the back button on the
/// left and — for a manager — edit and delete buttons on the right.
class _Header extends StatelessWidget {
  const _Header({
    required this.canManage,
    required this.submitting,
    required this.backToDay,
    required this.onEdit,
    required this.onDelete,
  });

  final bool canManage;
  final bool submitting;
  final String? backToDay;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final backToDay = this.backToDay;
    final backPath = (backToDay != null && backToDay.isNotEmpty)
        ? '${AppRoutes.eventDay}?date=$backToDay'
        : AppRoutes.events;
    final backLabel = (backToDay != null && backToDay.isNotEmpty)
        ? 'Back to Day'
        : 'Back to Events';
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          onPressed: () => context.go(backPath),
          icon: const Icon(Icons.arrow_back),
          label: Text(backLabel),
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
}

/// The main card: the event itself.
class _EventCard extends StatelessWidget {
  const _EventCard({
    required this.event,
    required this.readerZone,
    required this.actionError,
    required this.successMessage,
  });

  final EventResponse event;
  final String readerZone;
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
            _MetaRow(event: event, readerZone: readerZone),
            // **The banners sit here,** where the original put them: under the
            // title, above the description.
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
/// The original rendered these as a spaced row of icon-and-text items.
class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.event, required this.readerZone});

  final EventResponse event;
  final String readerZone;

  @override
  Widget build(BuildContext context) {
    final location = event.location;
    final time = event.timeIn(readerZone);
    final zoneSuffix = event.timezone == readerZone
        ? ''
        : ' · ${event.timezone}';

    return LayoutBuilder(
      builder: (context, constraints) => Wrap(
        spacing: 16,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _MetaItem(icon: Icons.event_note, text: event.dateIn(readerZone)),
          _MetaItem(
            icon: Icons.schedule,
            text: '$time (${event.durationMinutes} min)$zoneSuffix',
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
/// The original rendered it as a link to
/// `https://www.google.com/maps/search/?api=1&query={location}`.
///
/// **The link opens in a new tab,** as the original did with `target="_blank"`.
/// `url_launcher` is the one package this screen adds, and the reason is here:
/// a location that cannot be opened is a location that cannot be found, and
/// there is no way to open a URL from Flutter without one.
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
/// The original rendered this as a light box with a thick primary border down
/// its left edge.
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
/// The original rendered this as a responsive grid (one column on small screens,
/// two on wider ones) of small cards, each a quantity badge beside the item's
/// name.
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
class _Sidebar extends ConsumerWidget {
  const _Sidebar({
    required this.event,
    required this.readerZone,
    required this.canJoin,
    required this.canManage,
    required this.myRsvpStatus,
    required this.submitting,
    required this.backToDay,
    required this.onRsvp,
  });

  final EventResponse event;
  final String readerZone;
  final bool canJoin;
  final bool canManage;
  final String? myRsvpStatus;
  final bool submitting;
  final String? backToDay;
  final ValueChanged<String> onRsvp;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedOrganization = ref.watch(selectedOrganizationProvider);
    final showOrganizationName =
        selectedOrganization == null ||
        selectedOrganization.organizationId !=
            event.organization.organizationId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The panel fetches the events on this event's day, in this event's
        // organization, and marks this event's placement with a ghost marker.
        DayEventsPanel(
          date: event.dateIn(readerZone),
          organizationId: event.organization.organizationId.toString(),
          organizationName: showOrganizationName
              ? event.organization.name
              : null,
          excludeEventId: event.eventId.toString(),
          headerMode: DayEventsPanelHeaderMode.linkToDayView,
          marker: DayEventsPanelMarker(
            instant: event.instant,
            label: 'This event',
          ),
          eventDetailsBackToDay: backToDay,
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
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _AvailabilityButton(
                    label: 'Going',
                    icon: Icons.check_circle_outline,
                    color: TevenTheme.success,
                    selected: status == RsvpAvailability.accepted,
                    onPressed: submitting
                        ? null
                        : () => onRsvp(RsvpAvailability.accepted),
                  ),
                  _AvailabilityButton(
                    label: 'Maybe',
                    icon: Icons.help_outline,
                    color: theme.colorScheme.primary,
                    selected: status == RsvpAvailability.tentative,
                    onPressed: submitting
                        ? null
                        : () => onRsvp(RsvpAvailability.tentative),
                  ),
                  _AvailabilityButton(
                    label: 'Not Going',
                    icon: Icons.cancel_outlined,
                    color: TevenTheme.danger,
                    selected: status == RsvpAvailability.declined,
                    onPressed: submitting
                        ? null
                        : () => onRsvp(RsvpAvailability.declined),
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
            if (status != null && status != RsvpAvailability.needsAction) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: submitting
                    ? null
                    : () => onRsvp(RsvpAvailability.needsAction),
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

    final invited = event.rsvps
        .where((rsvp) => rsvp.availability == RsvpAvailability.needsAction)
        .toList();
    final confirmed = event.rsvps
        .where((rsvp) => rsvp.availability == RsvpAvailability.accepted)
        .toList();
    final tentative = event.rsvps
        .where((rsvp) => rsvp.availability == RsvpAvailability.tentative)
        .toList();
    final declined = event.rsvps
        .where((rsvp) => rsvp.availability == RsvpAvailability.declined)
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
            if (tentative.isNotEmpty) ...[
              const SizedBox(height: 16),
              _RosterSection(
                title: 'Tentative',
                color: theme.colorScheme.tertiary,
                icon: Icons.help_outline,
                members: tentative,
                emptyMessage: 'No tentative responses yet.',
              ),
            ],
            // **The declined list is for managers only.**
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

/// Compatibility alias: clearing a response now posts `needs_action`.
const String kRsvpCleared = RsvpAvailability.needsAction;
