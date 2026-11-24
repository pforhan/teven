import 'package:flutter/material.dart';

import '../core/theme/teven_theme.dart';
import '../models/event.dart';

/// Compact RSVP icon controls used across event surfaces.
///
/// Four actions: Yes (accepted), Maybe (tentative), No (declined), and Clear
/// (needs_action). The selected answer is filled; others are neutral. Tooltips
/// provide the label on hover and long press.
class RsvpButtons extends StatelessWidget {
  const RsvpButtons({
    super.key,
    required this.currentAvailability,
    required this.onSelected,
    this.enabled = true,
    this.wrap = true,
  });

  /// The user's current RSVP availability, or null/needsAction for no response.
  final String? currentAvailability;

  /// Called with the selected [RsvpAvailability] value.
  final ValueChanged<String> onSelected;

  /// Whether buttons accept input.
  final bool enabled;

  /// Whether buttons wrap onto multiple lines when space is tight.
  final bool wrap;

  @override
  Widget build(BuildContext context) {
    final current = currentAvailability == RsvpAvailability.needsAction
        ? null
        : currentAvailability;
    final children = [
      _RsvpIconButton(
        icon: Icons.check,
        tooltip: 'RSVP Yes',
        semanticLabel: 'RSVP Yes',
        selected: current == RsvpAvailability.accepted,
        selectedColor: TevenTheme.success,
        enabled: enabled,
        onPressed: () => onSelected(RsvpAvailability.accepted),
      ),
      _RsvpIconButton(
        icon: Icons.question_mark,
        tooltip: 'RSVP Maybe',
        semanticLabel: 'RSVP Maybe',
        selected: current == RsvpAvailability.tentative,
        selectedColor: Theme.of(context).colorScheme.primary,
        enabled: enabled,
        onPressed: () => onSelected(RsvpAvailability.tentative),
      ),
      _RsvpIconButton(
        icon: Icons.close,
        tooltip: 'RSVP No',
        semanticLabel: 'RSVP No',
        selected: current == RsvpAvailability.declined,
        selectedColor: TevenTheme.danger,
        enabled: enabled,
        onPressed: () => onSelected(RsvpAvailability.declined),
      ),
      _RsvpIconButton(
        icon: Icons.undo,
        tooltip: 'Clear RSVP',
        semanticLabel: 'Clear RSVP',
        selected: false,
        enabled: enabled && current != null,
        onPressed: () => onSelected(RsvpAvailability.needsAction),
      ),
    ];
    if (!wrap) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            children[i],
          ],
        ],
      );
    }
    return Wrap(spacing: 4, runSpacing: 4, children: children);
  }
}

/// Visual size for RSVP icon buttons.
const double kRsvpButtonSize = 44;

class _RsvpIconButton extends StatelessWidget {
  const _RsvpIconButton({
    required this.icon,
    required this.tooltip,
    required this.semanticLabel,
    required this.selected,
    required this.onPressed,
    required this.enabled,
    this.selectedColor,
  });

  final IconData icon;
  final String tooltip;
  final String semanticLabel;
  final bool selected;
  final VoidCallback onPressed;
  final bool enabled;
  final Color? selectedColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fill = selectedColor ?? scheme.primary;
    return IconButton(
      tooltip: tooltip,
      onPressed: enabled ? onPressed : null,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(
        minWidth: kRsvpButtonSize,
        minHeight: kRsvpButtonSize,
      ),
      style: IconButton.styleFrom(
        backgroundColor: selected ? fill : scheme.surfaceContainerHighest,
        foregroundColor: selected ? Colors.white : scheme.outline,
        disabledBackgroundColor: selected
            ? fill.withValues(alpha: 0.5)
            : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        disabledForegroundColor: selected
            ? Colors.white.withValues(alpha: 0.8)
            : scheme.outline.withValues(alpha: 0.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      icon: Icon(icon, size: 18, semanticLabel: semanticLabel),
    );
  }
}
