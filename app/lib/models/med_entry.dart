/// One medication taken for an event. Stored inside migraine_events.meds_taken as a JSON array.
class MedEntry {
  final String name;
  final String? dose;

  /// ISO-8601 UTC string, or null if not recorded.
  final String? time;

  /// Tri-state: true (helped) / false (didn't) / null (unknown).
  final bool? helped;

  const MedEntry({required this.name, this.dose, this.time, this.helped});

  Map<String, dynamic> toJson() => {
        'name': name,
        if (dose != null) 'dose': dose,
        if (time != null) 'time': time,
        if (helped != null) 'helped': helped,
      };

  factory MedEntry.fromJson(Map<String, dynamic> j) => MedEntry(
        name: j['name'] as String? ?? '',
        dose: j['dose'] as String?,
        time: j['time'] as String?,
        helped: j['helped'] as bool?,
      );
}
