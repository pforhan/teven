import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/layout/breakpoints.dart';
import '../models/organization.dart';
import '../providers/organization_controller.dart';
import '../providers/organization_list.dart';

/// Shows the organization picker and returns the chosen organization.
///
/// `null` means dismissed without choosing — by Cancel, by the barrier, or by
/// the back gesture.
///
/// Task 3.7: a bottom sheet on mobile, a centred dialog above it. The React
/// original was one modal (`QuickOrganizationPickerModal.tsx`) used at both
/// sizes, which on a phone put a 300px-tall list with a search box above it
/// into the middle of a small screen. A sheet anchors the same content to the
/// thumb and gets the full height; a dialog keeps the dismiss-on-outside-tap
/// affordance that a sheet's barrier mostly gives you anyway but a desktop user
/// expects.
///
/// Tablet counts as desktop here. A 700px-wide window has room for the
/// centred dialog, and the sheet's drag-to-dismiss would fight the rail's
/// own scrolling.
Future<OrganizationResponse?> showOrganizationPicker(
  BuildContext context, {
  String title = 'Select Organization',
  String message = 'Please select which organization this event belongs to.',
}) {
  final isMobile = context.layoutSize == LayoutSize.mobile;
  final show = isMobile
      ? showModalBottomSheet<OrganizationResponse>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (context) =>
              _OrganizationPickerSheet(title: title, message: message),
        )
      : showDialog<OrganizationResponse>(
          context: context,
          builder: (context) =>
              _OrganizationPickerDialog(title: title, message: message),
        );

  return show.then((selected) => selected);
}

/// The picker's content, shared by the sheet and the dialog.
///
/// They differ only in their container, so everything below the title is
/// shared rather than duplicated: the search filter, the loading and error
/// states, and the selection handler all behave identically at both sizes.
/// Task 9.2 flags the React `maxHeight: '300px'` for replacement; the list
/// here flexes instead.
class _OrganizationPicker extends ConsumerStatefulWidget {
  const _OrganizationPicker({
    required this.title,
    required this.message,
    required this.onSelected,
  });

  final String title;
  final String message;
  final ValueChanged<OrganizationResponse> onSelected;

  @override
  ConsumerState<_OrganizationPicker> createState() =>
      _OrganizationPickerState();
}

class _OrganizationPickerState extends ConsumerState<_OrganizationPicker> {
  /// `QuickOrganizationPickerModal.tsx:35` filters on a lowercased substring
  /// match. Reproduced rather than "improved" to a fuzzy match, because the
  /// picker is a switcher, not a search engine.
  String _searchTerm = '';

  /// Applies the selection, closes, and hands the choice back to the caller.
  ///
  /// `QuickOrganizationPickerModal.tsx:40-42` does all three: it writes the
  /// selection to `OrganizationContext`, notifies its parent, and hides.
  /// Persisting and notifying are separated here — [onSelected] persists, the
  /// `Navigator.pop` below returns the value — because a caller in Phase 6
  /// that *declines* a selection still wants the context untouched.
  Future<void> _select(OrganizationResponse organization) async {
    await ref
        .read(organizationControllerProvider.notifier)
        .select(organization);
    widget.onSelected(organization);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final organizations = ref.watch(organizationListProvider);
    final searchTerm = _searchTerm.toLowerCase();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(widget.title, style: theme.textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          widget.message,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.secondary,
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          autofocus: true,
          onChanged: (value) => setState(() => _searchTerm = value),
          decoration: const InputDecoration(
            hintText: 'Search organizations...',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 8),
        Flexible(child: _body(theme, organizations, searchTerm)),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  Widget _body(
    ThemeData theme,
    AsyncValue<List<OrganizationResponse>> organizations,
    String searchTerm,
  ) {
    // `QuickOrganizationPickerModal.tsx:25-27` swallows the failure and logs
    // it, which leaves the user staring at an empty list that reads exactly
    // like "there are no organizations". Worth showing.
    final error = organizations.whenOrNull(error: (error, stackTrace) => error);
    if (error != null) {
      return _Message(
        icon: Icons.error_outline,
        text: '$error',
        color: theme.colorScheme.error,
      );
    }

    return organizations.when(
      loading: () =>
          const _Message(icon: null, text: 'Loading organizations...'),
      data: (all) {
        final matches = all
            .where((org) => org.name.toLowerCase().contains(searchTerm))
            .toList();

        if (matches.isEmpty) {
          return const _Message(icon: null, text: 'No organizations found.');
        }

        return ListView.builder(
          shrinkWrap: true,
          itemCount: matches.length,
          itemBuilder: (context, index) {
            final organization = matches[index];
            return ListTile(
              title: Text(organization.name),
              trailing: Icon(
                Icons.chevron_right,
                color: theme.colorScheme.secondary,
              ),
              onTap: () async {
                await _select(organization);
                if (context.mounted) Navigator.of(context).pop(organization);
              },
            );
          },
        );
      },
      // The error arm is handled above; this one is unreachable.
      error: (error, stackTrace) => const SizedBox.shrink(),
    );
  }
}

class _OrganizationPickerSheet extends StatelessWidget {
  const _OrganizationPickerSheet({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        // `isScrollControlled` lets the sheet use most of the viewport, so the
        // search field has to be inset from the on-screen keyboard.
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 8,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
        ),
        child: _OrganizationPicker(
          title: title,
          message: message,
          onSelected: (_) {},
        ),
      ),
    );
  }
}

class _OrganizationPickerDialog extends StatelessWidget {
  const _OrganizationPickerDialog({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    // `AlertDialog` would lay out its own `title` above the content, and the
    // shared body renders a heading too. Only one of them is given it, so the
    // dialog shows a single heading rather than the same words twice.
    return AlertDialog(
      insetPadding: const EdgeInsets.all(24),
      contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      content: SizedBox(
        width: 420,
        child: _OrganizationPicker(
          title: title,
          message: message,
          onSelected: (_) {},
        ),
      ),
    );
  }
}

/// The empty, loading and error states, in one place.
class _Message extends StatelessWidget {
  const _Message({required this.text, this.icon, this.color});

  final String text;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ink = color ?? theme.colorScheme.secondary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: ink),
            const SizedBox(height: 8),
          ],
          Text(
            text,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: ink),
          ),
        ],
      ),
    );
  }
}
