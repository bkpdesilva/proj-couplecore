/// Local-time daily window during which reminder notifications are suppressed (FR-5, FR-50).
class QuietHours {
  const QuietHours({
    this.enabled = false,
    this.startHour = 22,
    this.endHour = 7,
  });

  final bool enabled;
  final int startHour;
  final int endHour;

  factory QuietHours.fromMap(Map<String, dynamic>? data) {
    if (data == null) return const QuietHours();
    return QuietHours(
      enabled: data['enabled'] as bool? ?? false,
      startHour: data['startHour'] as int? ?? 22,
      endHour: data['endHour'] as int? ?? 7,
    );
  }

  Map<String, dynamic> toMap() => {
        'enabled': enabled,
        'startHour': startHour,
        'endHour': endHour,
      };

  QuietHours copyWith({bool? enabled, int? startHour, int? endHour}) {
    return QuietHours(
      enabled: enabled ?? this.enabled,
      startHour: startHour ?? this.startHour,
      endHour: endHour ?? this.endHour,
    );
  }
}

class NotificationPrefs {
  const NotificationPrefs({
    this.moodReminders = true,
    this.calendarReminders = true,
    this.emergencyAlerts = true,
  });

  final bool moodReminders;
  final bool calendarReminders;
  final bool emergencyAlerts;

  factory NotificationPrefs.fromMap(Map<String, dynamic>? data) {
    if (data == null) return const NotificationPrefs();
    return NotificationPrefs(
      moodReminders: data['moodReminders'] as bool? ?? true,
      calendarReminders: data['calendarReminders'] as bool? ?? true,
      emergencyAlerts: data['emergencyAlerts'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
        'moodReminders': moodReminders,
        'calendarReminders': calendarReminders,
        'emergencyAlerts': emergencyAlerts,
      };

  NotificationPrefs copyWith({
    bool? moodReminders,
    bool? calendarReminders,
    bool? emergencyAlerts,
  }) {
    return NotificationPrefs(
      moodReminders: moodReminders ?? this.moodReminders,
      calendarReminders: calendarReminders ?? this.calendarReminders,
      emergencyAlerts: emergencyAlerts ?? this.emergencyAlerts,
    );
  }
}
