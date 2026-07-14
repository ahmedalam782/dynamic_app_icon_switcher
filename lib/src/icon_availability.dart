/// Parses remote icon availability config and merges it with natively shipped
/// icon names.
///
/// App icons are native resources resolved at install time. An HTTP API can
/// only control which *already-shipped* icons appear in a picker or are
/// selected via `active_icon` — it cannot introduce a new icon design without
/// a new binary.
class IconAvailability {
  IconAvailability._();

  /// Returns the intersection of [shippedIcons] (native aliases / plist) and
  /// [availableFromRemote], optionally filtered by [schedule] against [now].
  ///
  /// Icons listed remotely but missing from [shippedIcons] are dropped (they
  /// would fail with `ICON_NOT_FOUND` if passed to `setIcon`).
  static List<String> resolveAvailable({
    required List<String> shippedIcons,
    List<String>? availableFromRemote,
    List<IconScheduleEntry>? schedule,
    DateTime? now,
  }) {
    final shipped = shippedIcons
        .where((String name) => name.isNotEmpty && name != 'default')
        .toSet();

    Iterable<String> candidates;
    if (availableFromRemote == null) {
      candidates = shipped;
    } else {
      candidates = availableFromRemote.where(shipped.contains);
    }

    if (schedule == null || schedule.isEmpty) {
      return candidates.toList(growable: false);
    }

    final at = now ?? DateTime.now().toUtc();
    final activeBySchedule = <String>{};
    var hasMatchingWindow = false;

    for (final entry in schedule) {
      if (!shipped.contains(entry.icon)) {
        continue;
      }
      if (entry.isActiveAt(at)) {
        hasMatchingWindow = true;
        activeBySchedule.add(entry.icon);
      }
    }

    // If a schedule is provided but no window is active, fall back to the
    // remote/shipped intersection (schedule is additive filtering only when
    // at least one window matches).
    if (!hasMatchingWindow) {
      return candidates.toList(growable: false);
    }

    return candidates.where(activeBySchedule.contains).toList(growable: false);
  }

  /// Parses a JSON-like map from your HTTP API.
  ///
  /// Expected shape:
  /// ```json
  /// {
  ///   "available_icons": ["England", "Argentina"],
  ///   "icon_schedule": [
  ///     { "icon": "England", "from": "2026-06-01", "to": "2026-07-15" }
  ///   ]
  /// }
  /// ```
  static IconAvailabilityConfig parseConfig(Map<String, dynamic> json) {
    final available = (json['available_icons'] as List<dynamic>?)
            ?.map((dynamic e) => e.toString())
            .toList(growable: false) ??
        const <String>[];

    final scheduleRaw = json['icon_schedule'] as List<dynamic>? ?? const [];
    final schedule = scheduleRaw
        .whereType<Map>()
        .map((Map raw) {
          return IconScheduleEntry(
            icon: raw['icon']?.toString() ?? '',
            from: DateTime.tryParse(raw['from']?.toString() ?? ''),
            to: DateTime.tryParse(raw['to']?.toString() ?? ''),
          );
        })
        .where((IconScheduleEntry e) => e.icon.isNotEmpty)
        .toList(growable: false);

    return IconAvailabilityConfig(
      availableIcons: available,
      schedule: schedule,
    );
  }

  /// If the user still has a previously selected icon that is no longer in the
  /// picker, returns `'default'` so the app can fall back gracefully.
  static String fallbackIfUnavailable({
    required String currentIcon,
    required List<String> visibleIcons,
  }) {
    if (currentIcon == 'default' || currentIcon.isEmpty) {
      return 'default';
    }
    if (visibleIcons.contains(currentIcon)) {
      return currentIcon;
    }
    return 'default';
  }
}

/// Parsed remote icon availability payload.
class IconAvailabilityConfig {
  /// Creates a config from remote data.
  const IconAvailabilityConfig({
    required this.availableIcons,
    this.schedule = const <IconScheduleEntry>[],
  });

  /// Icon identifiers that should appear in the picker.
  final List<String> availableIcons;

  /// Optional date windows that further filter visibility.
  final List<IconScheduleEntry> schedule;
}

/// A schedule window for when an icon should appear in the picker.
class IconScheduleEntry {
  /// Creates a schedule entry. [from]/[to] are inclusive UTC calendar dates
  /// when parsed from `YYYY-MM-DD`.
  const IconScheduleEntry({
    required this.icon,
    this.from,
    this.to,
  });

  /// Native icon identifier (must match an alias / plist entry).
  final String icon;

  /// Inclusive start; `null` means no lower bound.
  final DateTime? from;

  /// Inclusive end; `null` means no upper bound.
  final DateTime? to;

  /// Whether this entry is active at [at].
  bool isActiveAt(DateTime at) {
    final instant = at.toUtc();
    if (from != null && instant.isBefore(_startOfDayUtc(from!))) {
      return false;
    }
    if (to != null && instant.isAfter(_endOfDayUtc(to!))) {
      return false;
    }
    return true;
  }

  static DateTime _startOfDayUtc(DateTime d) =>
      DateTime.utc(d.year, d.month, d.day);

  static DateTime _endOfDayUtc(DateTime d) =>
      DateTime.utc(d.year, d.month, d.day, 23, 59, 59, 999);
}
