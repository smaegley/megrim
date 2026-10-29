/// One non-drug relief method tried for an event (backlog #19). Stored inside
/// migraine_events.relief_tried as a JSON array, like [MedEntry] in meds_taken.
class ReliefEntry {
  final String name;

  /// Tri-state: true (helped) / false (didn't) / null (unknown).
  final bool? helped;

  const ReliefEntry({required this.name, this.helped});

  Map<String, dynamic> toJson() => {'name': name, if (helped != null) 'helped': helped};

  factory ReliefEntry.fromJson(Map<String, dynamic> j) =>
      ReliefEntry(name: j['name'] as String? ?? '', helped: j['helped'] as bool?);
}
