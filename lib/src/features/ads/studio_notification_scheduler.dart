import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../core/app_providers.dart';
import '../../core/notifications/local_notification_service.dart';

/// User preferences for Studio smart ad reminders.
@immutable
class StudioNotificationPrefs {
  const StudioNotificationPrefs({
    this.enabled = true,
    this.reminderTimes = const [
      TimeOfDay(hour: 10, minute: 0),
      TimeOfDay(hour: 14, minute: 0),
      TimeOfDay(hour: 18, minute: 0),
    ],
    this.suggestFromInventory = true,
    this.suggestWeeklyPromo = true,
  });

  final bool enabled;
  final List<TimeOfDay> reminderTimes;
  final bool suggestFromInventory;
  final bool suggestWeeklyPromo;

  StudioNotificationPrefs copyWith({
    bool? enabled,
    List<TimeOfDay>? reminderTimes,
    bool? suggestFromInventory,
    bool? suggestWeeklyPromo,
  }) {
    return StudioNotificationPrefs(
      enabled: enabled ?? this.enabled,
      reminderTimes: reminderTimes ?? this.reminderTimes,
      suggestFromInventory: suggestFromInventory ?? this.suggestFromInventory,
      suggestWeeklyPromo: suggestWeeklyPromo ?? this.suggestWeeklyPromo,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'reminderTimes': reminderTimes
            .map((t) => {'hour': t.hour, 'minute': t.minute})
            .toList(),
        'suggestFromInventory': suggestFromInventory,
        'suggestWeeklyPromo': suggestWeeklyPromo,
      };

  factory StudioNotificationPrefs.fromJson(Map<String, dynamic> json) {
    final rawTimes = json['reminderTimes'] as List<dynamic>?;
    final times = rawTimes
            ?.map(
              (e) => TimeOfDay(
                hour: (e['hour'] as num?)?.toInt() ?? 0,
                minute: (e['minute'] as num?)?.toInt() ?? 0,
              ),
            )
            .toList() ??
        const [
          TimeOfDay(hour: 10, minute: 0),
          TimeOfDay(hour: 14, minute: 0),
          TimeOfDay(hour: 18, minute: 0),
        ];

    return StudioNotificationPrefs(
      enabled: json['enabled'] as bool? ?? true,
      reminderTimes: times,
      suggestFromInventory: json['suggestFromInventory'] as bool? ?? true,
      suggestWeeklyPromo: json['suggestWeeklyPromo'] as bool? ?? true,
    );
  }
}

/// Manages Studio smart-ad reminder preferences and schedules/cancels the
/// corresponding local notifications.
class StudioNotificationPrefsNotifier
    extends StateNotifier<StudioNotificationPrefs> {
  StudioNotificationPrefsNotifier(this._prefs)
      : super(_load(_prefs));

  final SharedPreferences _prefs;
  static const _key = 'studio_notification_prefs_v1';
  static const _scheduledIdsKey = 'studio_notification_scheduled_ids_v1';
  static const _payload = '{"type":"studio","open_panel":"smart_ad","source":"notification"}';
  static const _idBase = 900000;

  static StudioNotificationPrefs _load(SharedPreferences prefs) {
    final raw = prefs.getString(_key);
    if (raw == null) return const StudioNotificationPrefs();
    try {
      return StudioNotificationPrefs.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (e) {
      debugPrint('[StudioNotificationScheduler] prefs parse failed: $e');
      return const StudioNotificationPrefs();
    }
  }

  Future<void> _persist() async {
    await _prefs.setString(_key, jsonEncode(state.toJson()));
  }

  Future<void> update(StudioNotificationPrefs value) async {
    state = value;
    await _persist();
    await refreshReminders();
  }

  Future<void> setEnabled(bool value) async {
    state = state.copyWith(enabled: value);
    await _persist();
    await refreshReminders();
  }

  Future<void> setSuggestFromInventory(bool value) async {
    state = state.copyWith(suggestFromInventory: value);
    await _persist();
    await refreshReminders();
  }

  Future<void> setSuggestWeeklyPromo(bool value) async {
    state = state.copyWith(suggestWeeklyPromo: value);
    await _persist();
    await refreshReminders();
  }

  /// Re-applies the current preference state to the local notification scheduler.
  ///
  /// Safe to call repeatedly: existing Studio reminders are cancelled first.
  /// Call after [LocalNotificationService.instance.init()] has completed.
  Future<void> refreshReminders() async {
    // Cancel only the IDs we previously scheduled.
    final previousIds = _prefs
            .getStringList(_scheduledIdsKey)
            ?.map(int.parse)
            .toList() ??
        <int>[];
    await LocalNotificationService.instance.cancelStudioReminders(ids: previousIds);

    if (!state.enabled) return;

    final scheduledIds = <int>[];
    for (final time in state.reminderTimes) {
      final id = _notificationIdFor(time);
      scheduledIds.add(id);
      final (title, body) = _messageFor(time);
      final scheduledDate = _nextOccurrence(time);
      try {
        await LocalNotificationService.instance.scheduleStudioReminder(
          id: id,
          title: title,
          body: body,
          scheduledDate: scheduledDate,
          payload: _payload,
        );
      } catch (e) {
        debugPrint('[StudioNotificationScheduler] schedule failed: $e');
      }
    }

    await _prefs.setStringList(
      _scheduledIdsKey,
      scheduledIds.map((id) => id.toString()).toList(),
    );
  }

  int _notificationIdFor(TimeOfDay time) {
    return _idBase + time.hour * 100 + time.minute;
  }

  tz.TZDateTime _nextOccurrence(TimeOfDay time) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  (String, String) _messageFor(TimeOfDay time) {
    final hour = time.hour;
    final isFriday = tz.TZDateTime.now(tz.local).weekday == DateTime.friday;

    if (state.suggestWeeklyPromo && isFriday && hour >= 14) {
      return (
        'Flash Friday? Create a sale ad in one tap',
        'Weekend shoppers are browsing — promote a deal now',
      );
    }

    if (hour < 12) {
      return _pickOne([
        ('Post your morning deal 🌅', 'Your customers are online — share a new ad'),
        if (state.suggestFromInventory)
          ('New inventory? Promote it now', 'You added items recently — turn them into ads'),
      ]);
    } else if (hour < 17) {
      return _pickOne([
        ('Your customers are online — share a new ad', 'Midday is a great time to post'),
        if (state.suggestFromInventory)
          ('Boost your newest items', 'Promote what you added today in one tap'),
      ]);
    } else {
      final nowWeekday = tz.TZDateTime.now(tz.local).weekday;
      return _pickOne([
        ('Evening promo push 🌙', 'End the day with a smart ad'),
        if (state.suggestWeeklyPromo &&
            (nowWeekday == DateTime.friday || nowWeekday == DateTime.saturday))
          ('Weekend promo ready?', 'Create a sale ad while customers unwind'),
      ]);
    }
  }

  (String, String) _pickOne(List<(String, String)> options) {
    if (options.isEmpty) {
      return ('Time to post an ad', 'Open Soko Studio and share something new');
    }
    return options[Random().nextInt(options.length)];
  }
}

final studioNotificationPrefsProvider =
    StateNotifierProvider<StudioNotificationPrefsNotifier, StudioNotificationPrefs>(
  (ref) => StudioNotificationPrefsNotifier(ref.read(sharedPreferencesProvider)),
);
