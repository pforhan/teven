/// Date formatting for the wire format the API uses.
///
/// `yyyy-MM-dd`, produced from a [DateTime]'s **local** calendar fields.
///
/// **Never `DateTime.toIso8601String().split('T')[0]`**, which is what the React
/// originals do in two places — `EventListPage.tsx:26-29` for the "Start Date"
/// default, and every `moment(...).format('YYYY-MM-DD')` in
/// `EventCalendar.tsx`. `toIso8601String()` converts to **UTC first**, so the
/// date it reports is the local date only for part of the world.
///
/// Concretely: at local midnight on Tuesday in `UTC+13` — Auckland, for
/// instance — `toIso8601String()` returns Sunday. The default start date would
/// silently be a day early, and the calendar's query window would be shifted by
/// a day for the same reason. Anywhere west of UTC it happens to be right,
/// which is why it survives: nobody testing in `UTC-5` sees anything wrong.
///
/// Formatted from the fields instead, this is a local calendar date by
/// construction and there is no zone to get wrong. This is the same reasoning
/// as `EventResponse.startAt`, which builds its [DateTime] from components
/// rather than parsing a concatenated string — see task 7.9.
library;

/// Formats [date] as `yyyy-MM-dd`, in its own local calendar fields.
///
/// The padded component form, not [DateFormat], because the output has no
/// locale in it: it is a wire value the server parses with `LocalDate.parse`,
/// and a locale-aware formatter would be free to hand back a different calendar
/// altogether. `intl` is still the right tool everywhere a date is shown to a
/// person — see the calendar header — which is where the *display* format is a
/// separate question from this one.
String formatLocalDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
