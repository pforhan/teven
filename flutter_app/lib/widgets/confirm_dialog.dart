import 'package:flutter/material.dart';

/// Confirms a destructive action, returning whether the user agreed.
///
/// Replaces the six `window.confirm` calls in the React list screens
/// (`CustomerList.tsx:60`, `InventoryList.tsx:60`, `OrganizationList.tsx:51`,
/// `UserList.tsx:79,94`, `EventDetails.tsx:46`).
///
/// The six differ only in the noun they name, so the dialog is shared and the
/// *consequence* stays at the call site — a refetch, a redirect, an
/// invitation that must outlive the user who accepted it. That split is the
/// point: `UserList.tsx:94` deletes an invitation, and `EventDetails.tsx:49`
/// navigates away rather than re-fetching, and neither belongs in a widget
/// that is only asking a question.
///
/// `window.confirm` was worth replacing on all three counts. It blocks the
/// whole browser tab, it cannot say *which* record is about to go, and it
/// cannot show the error the `catch` right beside it produces.
///
/// Returns `false` when the user cancels, and also when the dialog is
/// dismissed without an answer — the scrim, the back gesture, Escape. Those
/// are three ways of saying "no", and treating a dismissal as anything else is
/// how a dialog becomes a delete button with a delay on it.
Future<bool> confirmDestructiveAction(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Delete',
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            // Destructive, and coloured as such. Every one of the six React
            // call sites rendered an unremarkable native confirm, so nothing
            // here is a port — but a control that destroys something and one
            // that merely dismisses a dialog should not look alike.
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    ) ??
    false;
