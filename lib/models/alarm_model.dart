class AlarmModel {
  final String id;
  int hour;
  int minute;
  String label;
  bool isEnabled;
  List<bool> days; // Mon–Sun
  bool repeat;

  AlarmModel({
    required this.id,
    required this.hour,
    required this.minute,
    this.label = '',
    this.isEnabled = true,
    List<bool>? days,
    this.repeat = false,
  }) : days = days ?? List.filled(7, false);

  // ── Serialization ─────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'id': id,
        'hour': hour,
        'minute': minute,
        'label': label,
        'isEnabled': isEnabled,
        'days': days,
        'repeat': repeat,
      };

  factory AlarmModel.fromJson(Map<String, dynamic> json) => AlarmModel(
        id: json['id'] as String,
        hour: json['hour'] as int,
        minute: json['minute'] as int,
        label: json['label'] as String? ?? '',
        isEnabled: json['isEnabled'] as bool? ?? true,
        days: (json['days'] as List?)?.map((e) => e as bool).toList(),
        repeat: json['repeat'] as bool? ?? false,
      );

  // ── Time display ──────────────────────────────────────────

  String get timeString {
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  // ── Next occurrence ───────────────────────────────────────

  /// Returns the next DateTime this alarm will fire.
  DateTime get nextOccurrence {
    final now = DateTime.now();
    var candidate = DateTime(now.year, now.month, now.day, hour, minute);
    // If that time has already passed today, move to tomorrow
    if (!candidate.isAfter(now)) {
      candidate = candidate.add(const Duration(days: 1));
    }
    return candidate;
  }

  /// Calendar days from today until [nextOccurrence] (0 = today).
  int get daysUntilNext {
    final next = nextOccurrence;
    final now = DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day);
    final nextMidnight = DateTime(next.year, next.month, next.day);
    return nextMidnight.difference(todayMidnight).inDays;
  }
}
