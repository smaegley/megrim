import '../database/database.dart';

/// Wall-clock helpers for issue #17: an event belongs to the zone it was logged in.
///
/// Instants are stored in UTC. Before schema v2 every local-calendar concept (weekday, month,
/// season, time of day, which day is the migraine-day, the History calendar) was derived with
/// `toLocal()` — the phone's zone *at the moment the code ran*, so a traveller's analytics changed
/// with the phone's location and the stored weekday (enrichment time) could disagree with the
/// correlation tables (compute time). Now each event carries its UTC offset and everything
/// local-calendar goes through [wallClock]. A null offset (pre-v2 rows, imports without one) falls
/// back to `toLocal()`, i.e. exactly the old behaviour.

/// Wall-clock time of [utc] in the zone it was recorded in. With an offset the result is a
/// UTC-flagged DateTime whose *fields* read as the wall clock — use it for year/month/day/hour/
/// weekday, never for arithmetic against real instants. Without one it is a plain local DateTime.
DateTime wallClock(DateTime utc, int? offsetMinutes) => offsetMinutes == null
    ? utc.toLocal()
    : utc.toUtc().add(Duration(minutes: offsetMinutes));

/// The wall-clock calendar date of [utc] as a local-flagged midnight — the shape every day-keyed
/// map in analytics and the calendar already uses (`DateTime(y, m, d)`).
DateTime wallDate(DateTime utc, int? offsetMinutes) {
  final w = wallClock(utc, offsetMinutes);
  return DateTime(w.year, w.month, w.day);
}

/// A local-flagged DateTime with the wall-clock fields of [utc] — what a date/time picker seeds
/// from. (A nonexistent local time inside a DST gap on *this* phone normalises forward by an hour;
/// that only affects the picker's initial value, never stored data.)
DateTime wallClockNaive(DateTime utc, int? offsetMinutes) {
  final w = wallClock(utc, offsetMinutes);
  return DateTime(w.year, w.month, w.day, w.hour, w.minute);
}

/// The instant for wall-clock [naive] (fields only; its own zone flag is ignored) read in a zone
/// [offsetMinutes] east of UTC. Inverse of [wallClockNaive].
DateTime instantOf(DateTime naive, int offsetMinutes) => DateTime.utc(
      naive.year,
      naive.month,
      naive.day,
      naive.hour,
      naive.minute,
      naive.second,
    ).subtract(Duration(minutes: offsetMinutes));

/// The phone's UTC offset (minutes east) for [at] (default: now). For a local DateTime this is
/// DST-correct for that date.
int offsetMinutesOf([DateTime? at]) => (at ?? DateTime.now()).timeZoneOffset.inMinutes;

/// Every wall-clock calendar day an event covers, start date through end date inclusive, as
/// local-flagged midnights (backlog #10: a multi-day migraine counts on each day it spans). An
/// ongoing event (no end yet) or a malformed end-before-start covers only its start day, so an
/// entry the user forgot to end can't inflate a month. The end is read in [endOffsetMinutes]'s
/// zone, falling back to the start's, like [MigraineEventWallClock.endedWall]. Days are built with
/// constructor normalisation (`day + i`) rather than `.add(Duration(days: 1))` so a DST shift
/// inside the span can't drift the date (the `cb6671c` bug class).
///
/// Shared by the History calendar and the monthly migraine-day counts (backlog #17), so both
/// always agree on which days a migraine covers.
List<DateTime> daysCovered(
  DateTime startedAt,
  int? startOffsetMinutes,
  DateTime? endedAt,
  int? endOffsetMinutes,
) {
  final start = wallDate(startedAt, startOffsetMinutes);
  if (endedAt == null) return [start];
  final endDay = wallDate(endedAt, endOffsetMinutes ?? startOffsetMinutes);
  if (endDay.isBefore(start)) return [start];
  final out = <DateTime>[];
  for (var i = 0; ; i++) {
    final d = DateTime(start.year, start.month, start.day + i);
    if (d.isAfter(endDay)) break;
    out.add(d);
  }
  return out;
}

extension MigraineEventWallClock on MigraineEvent {
  DateTime get startedWall => wallClock(startedAt, startedAtOffsetMin);
  DateTime? get endedWall =>
      endedAt == null ? null : wallClock(endedAt!, endedAtOffsetMin ?? startedAtOffsetMin);
  DateTime get startedWallDate => wallDate(startedAt, startedAtOffsetMin);
}
