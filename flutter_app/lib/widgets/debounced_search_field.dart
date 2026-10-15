import 'dart:async';

import 'package:flutter/material.dart';

/// How long typing has to pause before a list is re-queried.
///
/// **Deliberate, where the React original was not.** Every list screen wires
/// `useState` on its search box straight into `useCallback`'s dependency list,
/// so each keystroke cancels and reissues a request — typing "Globex" fired
/// seven searches and raced seven responses into the same `setCustomers`.
/// Nothing debounced that, and nothing cancelled the superseded request either,
/// so task 9.6 is where the cancellation side gets its own treatment.
///
/// 300ms is the conventional figure and is short enough to feel immediate while
/// still collapsing a word into one request.
const Duration kSearchDebounce = Duration(milliseconds: 300);

/// A search box that reports a settled term rather than every keystroke.
///
/// Owns the controller, the debounce timer and their disposal, because that is
/// the part of the pattern that is identical on every list screen and the part
/// that is easy to get subtly wrong — a timer left pending fires into a
/// disposed state, and one that never cancels leaves the last few keystrokes to
/// race each other.
///
/// [onChanged] is called at most once per pause in typing. It is deliberately
/// *not* called on the initial empty value: a list that has never been
/// searched and a list searched for `""` are the same request, and
/// `ListQuery.toParams` drops an empty term anyway.
class DebouncedSearchField extends StatefulWidget {
  const DebouncedSearchField({
    super.key,
    required this.onChanged,
    this.hintText = 'Search by name...',
    this.labelText = 'Search',
  });

  final ValueChanged<String> onChanged;
  final String hintText;
  final String labelText;

  @override
  State<DebouncedSearchField> createState() => _DebouncedSearchFieldState();
}

class _DebouncedSearchFieldState extends State<DebouncedSearchField> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    // A pending debounce would otherwise fire into a disposed state.
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(kSearchDebounce, () {
      if (mounted) widget.onChanged(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    // `col-md-6` in the React originals, and a fixed `width: 250px` on the
    // event calendar's search box — task 9.2 is the pass that revisits fixed
    // widths. A bounded box beats both: it stops the field stretching across a
    // 4K window and stays usable at 500px.
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: TextField(
        controller: _controller,
        onChanged: _onChanged,
        decoration: InputDecoration(
          labelText: widget.labelText,
          hintText: widget.hintText,
          prefixIcon: const Icon(Icons.search),
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
