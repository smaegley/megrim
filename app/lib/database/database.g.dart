// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $MigraineEventsTable extends MigraineEvents
    with TableInfo<$MigraineEventsTable, MigraineEvent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MigraineEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endedAtMeta = const VerificationMeta(
    'endedAt',
  );
  @override
  late final GeneratedColumn<DateTime> endedAt = GeneratedColumn<DateTime>(
    'ended_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _severityMeta = const VerificationMeta(
    'severity',
  );
  @override
  late final GeneratedColumn<int> severity = GeneratedColumn<int>(
    'severity',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _locationHeadMeta = const VerificationMeta(
    'locationHead',
  );
  @override
  late final GeneratedColumn<String> locationHead = GeneratedColumn<String>(
    'location_head',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _auraPresentMeta = const VerificationMeta(
    'auraPresent',
  );
  @override
  late final GeneratedColumn<bool> auraPresent = GeneratedColumn<bool>(
    'aura_present',
    aliasedName,
    true,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("aura_present" IN (0, 1))',
    ),
  );
  static const VerificationMeta _auraDescriptionMeta = const VerificationMeta(
    'auraDescription',
  );
  @override
  late final GeneratedColumn<String> auraDescription = GeneratedColumn<String>(
    'aura_description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _medsTakenMeta = const VerificationMeta(
    'medsTaken',
  );
  @override
  late final GeneratedColumn<String> medsTaken = GeneratedColumn<String>(
    'meds_taken',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _triggersSuspectedMeta = const VerificationMeta(
    'triggersSuspected',
  );
  @override
  late final GeneratedColumn<String> triggersSuspected =
      GeneratedColumn<String>(
        'triggers_suspected',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _sleepHoursPriorMeta = const VerificationMeta(
    'sleepHoursPrior',
  );
  @override
  late final GeneratedColumn<double> sleepHoursPrior = GeneratedColumn<double>(
    'sleep_hours_prior',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _stressLevelMeta = const VerificationMeta(
    'stressLevel',
  );
  @override
  late final GeneratedColumn<int> stressLevel = GeneratedColumn<int>(
    'stress_level',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _foodsNotableMeta = const VerificationMeta(
    'foodsNotable',
  );
  @override
  late final GeneratedColumn<String> foodsNotable = GeneratedColumn<String>(
    'foods_notable',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _geoLatMeta = const VerificationMeta('geoLat');
  @override
  late final GeneratedColumn<double> geoLat = GeneratedColumn<double>(
    'geo_lat',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _geoLonMeta = const VerificationMeta('geoLon');
  @override
  late final GeneratedColumn<double> geoLon = GeneratedColumn<double>(
    'geo_lon',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _geoLabelMeta = const VerificationMeta(
    'geoLabel',
  );
  @override
  late final GeneratedColumn<String> geoLabel = GeneratedColumn<String>(
    'geo_label',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    startedAt,
    endedAt,
    severity,
    locationHead,
    auraPresent,
    auraDescription,
    medsTaken,
    triggersSuspected,
    sleepHoursPrior,
    stressLevel,
    foodsNotable,
    notes,
    geoLat,
    geoLon,
    geoLabel,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'migraine_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<MigraineEvent> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('ended_at')) {
      context.handle(
        _endedAtMeta,
        endedAt.isAcceptableOrUnknown(data['ended_at']!, _endedAtMeta),
      );
    }
    if (data.containsKey('severity')) {
      context.handle(
        _severityMeta,
        severity.isAcceptableOrUnknown(data['severity']!, _severityMeta),
      );
    }
    if (data.containsKey('location_head')) {
      context.handle(
        _locationHeadMeta,
        locationHead.isAcceptableOrUnknown(
          data['location_head']!,
          _locationHeadMeta,
        ),
      );
    }
    if (data.containsKey('aura_present')) {
      context.handle(
        _auraPresentMeta,
        auraPresent.isAcceptableOrUnknown(
          data['aura_present']!,
          _auraPresentMeta,
        ),
      );
    }
    if (data.containsKey('aura_description')) {
      context.handle(
        _auraDescriptionMeta,
        auraDescription.isAcceptableOrUnknown(
          data['aura_description']!,
          _auraDescriptionMeta,
        ),
      );
    }
    if (data.containsKey('meds_taken')) {
      context.handle(
        _medsTakenMeta,
        medsTaken.isAcceptableOrUnknown(data['meds_taken']!, _medsTakenMeta),
      );
    }
    if (data.containsKey('triggers_suspected')) {
      context.handle(
        _triggersSuspectedMeta,
        triggersSuspected.isAcceptableOrUnknown(
          data['triggers_suspected']!,
          _triggersSuspectedMeta,
        ),
      );
    }
    if (data.containsKey('sleep_hours_prior')) {
      context.handle(
        _sleepHoursPriorMeta,
        sleepHoursPrior.isAcceptableOrUnknown(
          data['sleep_hours_prior']!,
          _sleepHoursPriorMeta,
        ),
      );
    }
    if (data.containsKey('stress_level')) {
      context.handle(
        _stressLevelMeta,
        stressLevel.isAcceptableOrUnknown(
          data['stress_level']!,
          _stressLevelMeta,
        ),
      );
    }
    if (data.containsKey('foods_notable')) {
      context.handle(
        _foodsNotableMeta,
        foodsNotable.isAcceptableOrUnknown(
          data['foods_notable']!,
          _foodsNotableMeta,
        ),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('geo_lat')) {
      context.handle(
        _geoLatMeta,
        geoLat.isAcceptableOrUnknown(data['geo_lat']!, _geoLatMeta),
      );
    }
    if (data.containsKey('geo_lon')) {
      context.handle(
        _geoLonMeta,
        geoLon.isAcceptableOrUnknown(data['geo_lon']!, _geoLonMeta),
      );
    }
    if (data.containsKey('geo_label')) {
      context.handle(
        _geoLabelMeta,
        geoLabel.isAcceptableOrUnknown(data['geo_label']!, _geoLabelMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MigraineEvent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MigraineEvent(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      )!,
      endedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}ended_at'],
      ),
      severity: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}severity'],
      ),
      locationHead: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}location_head'],
      ),
      auraPresent: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}aura_present'],
      ),
      auraDescription: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}aura_description'],
      ),
      medsTaken: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}meds_taken'],
      ),
      triggersSuspected: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}triggers_suspected'],
      ),
      sleepHoursPrior: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}sleep_hours_prior'],
      ),
      stressLevel: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}stress_level'],
      ),
      foodsNotable: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}foods_notable'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      geoLat: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}geo_lat'],
      ),
      geoLon: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}geo_lon'],
      ),
      geoLabel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}geo_label'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $MigraineEventsTable createAlias(String alias) {
    return $MigraineEventsTable(attachedDatabase, alias);
  }
}

class MigraineEvent extends DataClass implements Insertable<MigraineEvent> {
  /// UUIDv4, client-generated.
  final String id;
  final DateTime startedAt;

  /// null = ongoing.
  final DateTime? endedAt;

  /// 1–10.
  final int? severity;

  /// JSON array of strings (vocab: head_location).
  final String? locationHead;

  /// Tri-state: true / false / null(unknown).
  final bool? auraPresent;
  final String? auraDescription;

  /// JSON: [{name, dose, time, helped}].
  final String? medsTaken;

  /// JSON array of strings (vocab: trigger).
  final String? triggersSuspected;
  final double? sleepHoursPrior;

  /// 1–5.
  final int? stressLevel;

  /// JSON array of strings.
  final String? foodsNotable;
  final String? notes;

  /// Rounded to 2 decimals (~1 km) at capture time — precise coords are never stored.
  final double? geoLat;
  final double? geoLon;
  final String? geoLabel;
  final DateTime createdAt;
  final DateTime updatedAt;
  const MigraineEvent({
    required this.id,
    required this.startedAt,
    this.endedAt,
    this.severity,
    this.locationHead,
    this.auraPresent,
    this.auraDescription,
    this.medsTaken,
    this.triggersSuspected,
    this.sleepHoursPrior,
    this.stressLevel,
    this.foodsNotable,
    this.notes,
    this.geoLat,
    this.geoLon,
    this.geoLabel,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['started_at'] = Variable<DateTime>(startedAt);
    if (!nullToAbsent || endedAt != null) {
      map['ended_at'] = Variable<DateTime>(endedAt);
    }
    if (!nullToAbsent || severity != null) {
      map['severity'] = Variable<int>(severity);
    }
    if (!nullToAbsent || locationHead != null) {
      map['location_head'] = Variable<String>(locationHead);
    }
    if (!nullToAbsent || auraPresent != null) {
      map['aura_present'] = Variable<bool>(auraPresent);
    }
    if (!nullToAbsent || auraDescription != null) {
      map['aura_description'] = Variable<String>(auraDescription);
    }
    if (!nullToAbsent || medsTaken != null) {
      map['meds_taken'] = Variable<String>(medsTaken);
    }
    if (!nullToAbsent || triggersSuspected != null) {
      map['triggers_suspected'] = Variable<String>(triggersSuspected);
    }
    if (!nullToAbsent || sleepHoursPrior != null) {
      map['sleep_hours_prior'] = Variable<double>(sleepHoursPrior);
    }
    if (!nullToAbsent || stressLevel != null) {
      map['stress_level'] = Variable<int>(stressLevel);
    }
    if (!nullToAbsent || foodsNotable != null) {
      map['foods_notable'] = Variable<String>(foodsNotable);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    if (!nullToAbsent || geoLat != null) {
      map['geo_lat'] = Variable<double>(geoLat);
    }
    if (!nullToAbsent || geoLon != null) {
      map['geo_lon'] = Variable<double>(geoLon);
    }
    if (!nullToAbsent || geoLabel != null) {
      map['geo_label'] = Variable<String>(geoLabel);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  MigraineEventsCompanion toCompanion(bool nullToAbsent) {
    return MigraineEventsCompanion(
      id: Value(id),
      startedAt: Value(startedAt),
      endedAt: endedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(endedAt),
      severity: severity == null && nullToAbsent
          ? const Value.absent()
          : Value(severity),
      locationHead: locationHead == null && nullToAbsent
          ? const Value.absent()
          : Value(locationHead),
      auraPresent: auraPresent == null && nullToAbsent
          ? const Value.absent()
          : Value(auraPresent),
      auraDescription: auraDescription == null && nullToAbsent
          ? const Value.absent()
          : Value(auraDescription),
      medsTaken: medsTaken == null && nullToAbsent
          ? const Value.absent()
          : Value(medsTaken),
      triggersSuspected: triggersSuspected == null && nullToAbsent
          ? const Value.absent()
          : Value(triggersSuspected),
      sleepHoursPrior: sleepHoursPrior == null && nullToAbsent
          ? const Value.absent()
          : Value(sleepHoursPrior),
      stressLevel: stressLevel == null && nullToAbsent
          ? const Value.absent()
          : Value(stressLevel),
      foodsNotable: foodsNotable == null && nullToAbsent
          ? const Value.absent()
          : Value(foodsNotable),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      geoLat: geoLat == null && nullToAbsent
          ? const Value.absent()
          : Value(geoLat),
      geoLon: geoLon == null && nullToAbsent
          ? const Value.absent()
          : Value(geoLon),
      geoLabel: geoLabel == null && nullToAbsent
          ? const Value.absent()
          : Value(geoLabel),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory MigraineEvent.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MigraineEvent(
      id: serializer.fromJson<String>(json['id']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      endedAt: serializer.fromJson<DateTime?>(json['endedAt']),
      severity: serializer.fromJson<int?>(json['severity']),
      locationHead: serializer.fromJson<String?>(json['locationHead']),
      auraPresent: serializer.fromJson<bool?>(json['auraPresent']),
      auraDescription: serializer.fromJson<String?>(json['auraDescription']),
      medsTaken: serializer.fromJson<String?>(json['medsTaken']),
      triggersSuspected: serializer.fromJson<String?>(
        json['triggersSuspected'],
      ),
      sleepHoursPrior: serializer.fromJson<double?>(json['sleepHoursPrior']),
      stressLevel: serializer.fromJson<int?>(json['stressLevel']),
      foodsNotable: serializer.fromJson<String?>(json['foodsNotable']),
      notes: serializer.fromJson<String?>(json['notes']),
      geoLat: serializer.fromJson<double?>(json['geoLat']),
      geoLon: serializer.fromJson<double?>(json['geoLon']),
      geoLabel: serializer.fromJson<String?>(json['geoLabel']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'endedAt': serializer.toJson<DateTime?>(endedAt),
      'severity': serializer.toJson<int?>(severity),
      'locationHead': serializer.toJson<String?>(locationHead),
      'auraPresent': serializer.toJson<bool?>(auraPresent),
      'auraDescription': serializer.toJson<String?>(auraDescription),
      'medsTaken': serializer.toJson<String?>(medsTaken),
      'triggersSuspected': serializer.toJson<String?>(triggersSuspected),
      'sleepHoursPrior': serializer.toJson<double?>(sleepHoursPrior),
      'stressLevel': serializer.toJson<int?>(stressLevel),
      'foodsNotable': serializer.toJson<String?>(foodsNotable),
      'notes': serializer.toJson<String?>(notes),
      'geoLat': serializer.toJson<double?>(geoLat),
      'geoLon': serializer.toJson<double?>(geoLon),
      'geoLabel': serializer.toJson<String?>(geoLabel),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  MigraineEvent copyWith({
    String? id,
    DateTime? startedAt,
    Value<DateTime?> endedAt = const Value.absent(),
    Value<int?> severity = const Value.absent(),
    Value<String?> locationHead = const Value.absent(),
    Value<bool?> auraPresent = const Value.absent(),
    Value<String?> auraDescription = const Value.absent(),
    Value<String?> medsTaken = const Value.absent(),
    Value<String?> triggersSuspected = const Value.absent(),
    Value<double?> sleepHoursPrior = const Value.absent(),
    Value<int?> stressLevel = const Value.absent(),
    Value<String?> foodsNotable = const Value.absent(),
    Value<String?> notes = const Value.absent(),
    Value<double?> geoLat = const Value.absent(),
    Value<double?> geoLon = const Value.absent(),
    Value<String?> geoLabel = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => MigraineEvent(
    id: id ?? this.id,
    startedAt: startedAt ?? this.startedAt,
    endedAt: endedAt.present ? endedAt.value : this.endedAt,
    severity: severity.present ? severity.value : this.severity,
    locationHead: locationHead.present ? locationHead.value : this.locationHead,
    auraPresent: auraPresent.present ? auraPresent.value : this.auraPresent,
    auraDescription: auraDescription.present
        ? auraDescription.value
        : this.auraDescription,
    medsTaken: medsTaken.present ? medsTaken.value : this.medsTaken,
    triggersSuspected: triggersSuspected.present
        ? triggersSuspected.value
        : this.triggersSuspected,
    sleepHoursPrior: sleepHoursPrior.present
        ? sleepHoursPrior.value
        : this.sleepHoursPrior,
    stressLevel: stressLevel.present ? stressLevel.value : this.stressLevel,
    foodsNotable: foodsNotable.present ? foodsNotable.value : this.foodsNotable,
    notes: notes.present ? notes.value : this.notes,
    geoLat: geoLat.present ? geoLat.value : this.geoLat,
    geoLon: geoLon.present ? geoLon.value : this.geoLon,
    geoLabel: geoLabel.present ? geoLabel.value : this.geoLabel,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  MigraineEvent copyWithCompanion(MigraineEventsCompanion data) {
    return MigraineEvent(
      id: data.id.present ? data.id.value : this.id,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      endedAt: data.endedAt.present ? data.endedAt.value : this.endedAt,
      severity: data.severity.present ? data.severity.value : this.severity,
      locationHead: data.locationHead.present
          ? data.locationHead.value
          : this.locationHead,
      auraPresent: data.auraPresent.present
          ? data.auraPresent.value
          : this.auraPresent,
      auraDescription: data.auraDescription.present
          ? data.auraDescription.value
          : this.auraDescription,
      medsTaken: data.medsTaken.present ? data.medsTaken.value : this.medsTaken,
      triggersSuspected: data.triggersSuspected.present
          ? data.triggersSuspected.value
          : this.triggersSuspected,
      sleepHoursPrior: data.sleepHoursPrior.present
          ? data.sleepHoursPrior.value
          : this.sleepHoursPrior,
      stressLevel: data.stressLevel.present
          ? data.stressLevel.value
          : this.stressLevel,
      foodsNotable: data.foodsNotable.present
          ? data.foodsNotable.value
          : this.foodsNotable,
      notes: data.notes.present ? data.notes.value : this.notes,
      geoLat: data.geoLat.present ? data.geoLat.value : this.geoLat,
      geoLon: data.geoLon.present ? data.geoLon.value : this.geoLon,
      geoLabel: data.geoLabel.present ? data.geoLabel.value : this.geoLabel,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MigraineEvent(')
          ..write('id: $id, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('severity: $severity, ')
          ..write('locationHead: $locationHead, ')
          ..write('auraPresent: $auraPresent, ')
          ..write('auraDescription: $auraDescription, ')
          ..write('medsTaken: $medsTaken, ')
          ..write('triggersSuspected: $triggersSuspected, ')
          ..write('sleepHoursPrior: $sleepHoursPrior, ')
          ..write('stressLevel: $stressLevel, ')
          ..write('foodsNotable: $foodsNotable, ')
          ..write('notes: $notes, ')
          ..write('geoLat: $geoLat, ')
          ..write('geoLon: $geoLon, ')
          ..write('geoLabel: $geoLabel, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    startedAt,
    endedAt,
    severity,
    locationHead,
    auraPresent,
    auraDescription,
    medsTaken,
    triggersSuspected,
    sleepHoursPrior,
    stressLevel,
    foodsNotable,
    notes,
    geoLat,
    geoLon,
    geoLabel,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MigraineEvent &&
          other.id == this.id &&
          other.startedAt == this.startedAt &&
          other.endedAt == this.endedAt &&
          other.severity == this.severity &&
          other.locationHead == this.locationHead &&
          other.auraPresent == this.auraPresent &&
          other.auraDescription == this.auraDescription &&
          other.medsTaken == this.medsTaken &&
          other.triggersSuspected == this.triggersSuspected &&
          other.sleepHoursPrior == this.sleepHoursPrior &&
          other.stressLevel == this.stressLevel &&
          other.foodsNotable == this.foodsNotable &&
          other.notes == this.notes &&
          other.geoLat == this.geoLat &&
          other.geoLon == this.geoLon &&
          other.geoLabel == this.geoLabel &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class MigraineEventsCompanion extends UpdateCompanion<MigraineEvent> {
  final Value<String> id;
  final Value<DateTime> startedAt;
  final Value<DateTime?> endedAt;
  final Value<int?> severity;
  final Value<String?> locationHead;
  final Value<bool?> auraPresent;
  final Value<String?> auraDescription;
  final Value<String?> medsTaken;
  final Value<String?> triggersSuspected;
  final Value<double?> sleepHoursPrior;
  final Value<int?> stressLevel;
  final Value<String?> foodsNotable;
  final Value<String?> notes;
  final Value<double?> geoLat;
  final Value<double?> geoLon;
  final Value<String?> geoLabel;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const MigraineEventsCompanion({
    this.id = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.endedAt = const Value.absent(),
    this.severity = const Value.absent(),
    this.locationHead = const Value.absent(),
    this.auraPresent = const Value.absent(),
    this.auraDescription = const Value.absent(),
    this.medsTaken = const Value.absent(),
    this.triggersSuspected = const Value.absent(),
    this.sleepHoursPrior = const Value.absent(),
    this.stressLevel = const Value.absent(),
    this.foodsNotable = const Value.absent(),
    this.notes = const Value.absent(),
    this.geoLat = const Value.absent(),
    this.geoLon = const Value.absent(),
    this.geoLabel = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MigraineEventsCompanion.insert({
    required String id,
    required DateTime startedAt,
    this.endedAt = const Value.absent(),
    this.severity = const Value.absent(),
    this.locationHead = const Value.absent(),
    this.auraPresent = const Value.absent(),
    this.auraDescription = const Value.absent(),
    this.medsTaken = const Value.absent(),
    this.triggersSuspected = const Value.absent(),
    this.sleepHoursPrior = const Value.absent(),
    this.stressLevel = const Value.absent(),
    this.foodsNotable = const Value.absent(),
    this.notes = const Value.absent(),
    this.geoLat = const Value.absent(),
    this.geoLon = const Value.absent(),
    this.geoLabel = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       startedAt = Value(startedAt),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<MigraineEvent> custom({
    Expression<String>? id,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? endedAt,
    Expression<int>? severity,
    Expression<String>? locationHead,
    Expression<bool>? auraPresent,
    Expression<String>? auraDescription,
    Expression<String>? medsTaken,
    Expression<String>? triggersSuspected,
    Expression<double>? sleepHoursPrior,
    Expression<int>? stressLevel,
    Expression<String>? foodsNotable,
    Expression<String>? notes,
    Expression<double>? geoLat,
    Expression<double>? geoLon,
    Expression<String>? geoLabel,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (startedAt != null) 'started_at': startedAt,
      if (endedAt != null) 'ended_at': endedAt,
      if (severity != null) 'severity': severity,
      if (locationHead != null) 'location_head': locationHead,
      if (auraPresent != null) 'aura_present': auraPresent,
      if (auraDescription != null) 'aura_description': auraDescription,
      if (medsTaken != null) 'meds_taken': medsTaken,
      if (triggersSuspected != null) 'triggers_suspected': triggersSuspected,
      if (sleepHoursPrior != null) 'sleep_hours_prior': sleepHoursPrior,
      if (stressLevel != null) 'stress_level': stressLevel,
      if (foodsNotable != null) 'foods_notable': foodsNotable,
      if (notes != null) 'notes': notes,
      if (geoLat != null) 'geo_lat': geoLat,
      if (geoLon != null) 'geo_lon': geoLon,
      if (geoLabel != null) 'geo_label': geoLabel,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MigraineEventsCompanion copyWith({
    Value<String>? id,
    Value<DateTime>? startedAt,
    Value<DateTime?>? endedAt,
    Value<int?>? severity,
    Value<String?>? locationHead,
    Value<bool?>? auraPresent,
    Value<String?>? auraDescription,
    Value<String?>? medsTaken,
    Value<String?>? triggersSuspected,
    Value<double?>? sleepHoursPrior,
    Value<int?>? stressLevel,
    Value<String?>? foodsNotable,
    Value<String?>? notes,
    Value<double?>? geoLat,
    Value<double?>? geoLon,
    Value<String?>? geoLabel,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return MigraineEventsCompanion(
      id: id ?? this.id,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      severity: severity ?? this.severity,
      locationHead: locationHead ?? this.locationHead,
      auraPresent: auraPresent ?? this.auraPresent,
      auraDescription: auraDescription ?? this.auraDescription,
      medsTaken: medsTaken ?? this.medsTaken,
      triggersSuspected: triggersSuspected ?? this.triggersSuspected,
      sleepHoursPrior: sleepHoursPrior ?? this.sleepHoursPrior,
      stressLevel: stressLevel ?? this.stressLevel,
      foodsNotable: foodsNotable ?? this.foodsNotable,
      notes: notes ?? this.notes,
      geoLat: geoLat ?? this.geoLat,
      geoLon: geoLon ?? this.geoLon,
      geoLabel: geoLabel ?? this.geoLabel,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (endedAt.present) {
      map['ended_at'] = Variable<DateTime>(endedAt.value);
    }
    if (severity.present) {
      map['severity'] = Variable<int>(severity.value);
    }
    if (locationHead.present) {
      map['location_head'] = Variable<String>(locationHead.value);
    }
    if (auraPresent.present) {
      map['aura_present'] = Variable<bool>(auraPresent.value);
    }
    if (auraDescription.present) {
      map['aura_description'] = Variable<String>(auraDescription.value);
    }
    if (medsTaken.present) {
      map['meds_taken'] = Variable<String>(medsTaken.value);
    }
    if (triggersSuspected.present) {
      map['triggers_suspected'] = Variable<String>(triggersSuspected.value);
    }
    if (sleepHoursPrior.present) {
      map['sleep_hours_prior'] = Variable<double>(sleepHoursPrior.value);
    }
    if (stressLevel.present) {
      map['stress_level'] = Variable<int>(stressLevel.value);
    }
    if (foodsNotable.present) {
      map['foods_notable'] = Variable<String>(foodsNotable.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (geoLat.present) {
      map['geo_lat'] = Variable<double>(geoLat.value);
    }
    if (geoLon.present) {
      map['geo_lon'] = Variable<double>(geoLon.value);
    }
    if (geoLabel.present) {
      map['geo_label'] = Variable<String>(geoLabel.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MigraineEventsCompanion(')
          ..write('id: $id, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('severity: $severity, ')
          ..write('locationHead: $locationHead, ')
          ..write('auraPresent: $auraPresent, ')
          ..write('auraDescription: $auraDescription, ')
          ..write('medsTaken: $medsTaken, ')
          ..write('triggersSuspected: $triggersSuspected, ')
          ..write('sleepHoursPrior: $sleepHoursPrior, ')
          ..write('stressLevel: $stressLevel, ')
          ..write('foodsNotable: $foodsNotable, ')
          ..write('notes: $notes, ')
          ..write('geoLat: $geoLat, ')
          ..write('geoLon: $geoLon, ')
          ..write('geoLabel: $geoLabel, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DerivedFactorsTable extends DerivedFactors
    with TableInfo<$DerivedFactorsTable, DerivedFactor> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DerivedFactorsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _eventIdMeta = const VerificationMeta(
    'eventId',
  );
  @override
  late final GeneratedColumn<String> eventId = GeneratedColumn<String>(
    'event_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES migraine_events (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _dayOfWeekMeta = const VerificationMeta(
    'dayOfWeek',
  );
  @override
  late final GeneratedColumn<int> dayOfWeek = GeneratedColumn<int>(
    'day_of_week',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _seasonMeta = const VerificationMeta('season');
  @override
  late final GeneratedColumn<String> season = GeneratedColumn<String>(
    'season',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _timeOfDayBucketMeta = const VerificationMeta(
    'timeOfDayBucket',
  );
  @override
  late final GeneratedColumn<String> timeOfDayBucket = GeneratedColumn<String>(
    'time_of_day_bucket',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _daylightHoursMeta = const VerificationMeta(
    'daylightHours',
  );
  @override
  late final GeneratedColumn<double> daylightHours = GeneratedColumn<double>(
    'daylight_hours',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sunriseUtcMeta = const VerificationMeta(
    'sunriseUtc',
  );
  @override
  late final GeneratedColumn<DateTime> sunriseUtc = GeneratedColumn<DateTime>(
    'sunrise_utc',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sunsetUtcMeta = const VerificationMeta(
    'sunsetUtc',
  );
  @override
  late final GeneratedColumn<DateTime> sunsetUtc = GeneratedColumn<DateTime>(
    'sunset_utc',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _moonPhaseMeta = const VerificationMeta(
    'moonPhase',
  );
  @override
  late final GeneratedColumn<String> moonPhase = GeneratedColumn<String>(
    'moon_phase',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _moonIlluminationMeta = const VerificationMeta(
    'moonIllumination',
  );
  @override
  late final GeneratedColumn<double> moonIllumination = GeneratedColumn<double>(
    'moon_illumination',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tempCMeta = const VerificationMeta('tempC');
  @override
  late final GeneratedColumn<double> tempC = GeneratedColumn<double>(
    'temp_c',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _humidityPctMeta = const VerificationMeta(
    'humidityPct',
  );
  @override
  late final GeneratedColumn<double> humidityPct = GeneratedColumn<double>(
    'humidity_pct',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pressureHpaMeta = const VerificationMeta(
    'pressureHpa',
  );
  @override
  late final GeneratedColumn<double> pressureHpa = GeneratedColumn<double>(
    'pressure_hpa',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _precipitationMmMeta = const VerificationMeta(
    'precipitationMm',
  );
  @override
  late final GeneratedColumn<double> precipitationMm = GeneratedColumn<double>(
    'precipitation_mm',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pressureDelta24hMeta = const VerificationMeta(
    'pressureDelta24h',
  );
  @override
  late final GeneratedColumn<double> pressureDelta24h = GeneratedColumn<double>(
    'pressure_delta24h',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pressureDelta48hMeta = const VerificationMeta(
    'pressureDelta48h',
  );
  @override
  late final GeneratedColumn<double> pressureDelta48h = GeneratedColumn<double>(
    'pressure_delta48h',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _aqiMeta = const VerificationMeta('aqi');
  @override
  late final GeneratedColumn<int> aqi = GeneratedColumn<int>(
    'aqi',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _enrichedAtMeta = const VerificationMeta(
    'enrichedAt',
  );
  @override
  late final GeneratedColumn<DateTime> enrichedAt = GeneratedColumn<DateTime>(
    'enriched_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _enrichErrorMeta = const VerificationMeta(
    'enrichError',
  );
  @override
  late final GeneratedColumn<String> enrichError = GeneratedColumn<String>(
    'enrich_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    eventId,
    dayOfWeek,
    season,
    timeOfDayBucket,
    daylightHours,
    sunriseUtc,
    sunsetUtc,
    moonPhase,
    moonIllumination,
    tempC,
    humidityPct,
    pressureHpa,
    precipitationMm,
    pressureDelta24h,
    pressureDelta48h,
    aqi,
    enrichedAt,
    enrichError,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'derived_factors';
  @override
  VerificationContext validateIntegrity(
    Insertable<DerivedFactor> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('event_id')) {
      context.handle(
        _eventIdMeta,
        eventId.isAcceptableOrUnknown(data['event_id']!, _eventIdMeta),
      );
    } else if (isInserting) {
      context.missing(_eventIdMeta);
    }
    if (data.containsKey('day_of_week')) {
      context.handle(
        _dayOfWeekMeta,
        dayOfWeek.isAcceptableOrUnknown(data['day_of_week']!, _dayOfWeekMeta),
      );
    }
    if (data.containsKey('season')) {
      context.handle(
        _seasonMeta,
        season.isAcceptableOrUnknown(data['season']!, _seasonMeta),
      );
    }
    if (data.containsKey('time_of_day_bucket')) {
      context.handle(
        _timeOfDayBucketMeta,
        timeOfDayBucket.isAcceptableOrUnknown(
          data['time_of_day_bucket']!,
          _timeOfDayBucketMeta,
        ),
      );
    }
    if (data.containsKey('daylight_hours')) {
      context.handle(
        _daylightHoursMeta,
        daylightHours.isAcceptableOrUnknown(
          data['daylight_hours']!,
          _daylightHoursMeta,
        ),
      );
    }
    if (data.containsKey('sunrise_utc')) {
      context.handle(
        _sunriseUtcMeta,
        sunriseUtc.isAcceptableOrUnknown(data['sunrise_utc']!, _sunriseUtcMeta),
      );
    }
    if (data.containsKey('sunset_utc')) {
      context.handle(
        _sunsetUtcMeta,
        sunsetUtc.isAcceptableOrUnknown(data['sunset_utc']!, _sunsetUtcMeta),
      );
    }
    if (data.containsKey('moon_phase')) {
      context.handle(
        _moonPhaseMeta,
        moonPhase.isAcceptableOrUnknown(data['moon_phase']!, _moonPhaseMeta),
      );
    }
    if (data.containsKey('moon_illumination')) {
      context.handle(
        _moonIlluminationMeta,
        moonIllumination.isAcceptableOrUnknown(
          data['moon_illumination']!,
          _moonIlluminationMeta,
        ),
      );
    }
    if (data.containsKey('temp_c')) {
      context.handle(
        _tempCMeta,
        tempC.isAcceptableOrUnknown(data['temp_c']!, _tempCMeta),
      );
    }
    if (data.containsKey('humidity_pct')) {
      context.handle(
        _humidityPctMeta,
        humidityPct.isAcceptableOrUnknown(
          data['humidity_pct']!,
          _humidityPctMeta,
        ),
      );
    }
    if (data.containsKey('pressure_hpa')) {
      context.handle(
        _pressureHpaMeta,
        pressureHpa.isAcceptableOrUnknown(
          data['pressure_hpa']!,
          _pressureHpaMeta,
        ),
      );
    }
    if (data.containsKey('precipitation_mm')) {
      context.handle(
        _precipitationMmMeta,
        precipitationMm.isAcceptableOrUnknown(
          data['precipitation_mm']!,
          _precipitationMmMeta,
        ),
      );
    }
    if (data.containsKey('pressure_delta24h')) {
      context.handle(
        _pressureDelta24hMeta,
        pressureDelta24h.isAcceptableOrUnknown(
          data['pressure_delta24h']!,
          _pressureDelta24hMeta,
        ),
      );
    }
    if (data.containsKey('pressure_delta48h')) {
      context.handle(
        _pressureDelta48hMeta,
        pressureDelta48h.isAcceptableOrUnknown(
          data['pressure_delta48h']!,
          _pressureDelta48hMeta,
        ),
      );
    }
    if (data.containsKey('aqi')) {
      context.handle(
        _aqiMeta,
        aqi.isAcceptableOrUnknown(data['aqi']!, _aqiMeta),
      );
    }
    if (data.containsKey('enriched_at')) {
      context.handle(
        _enrichedAtMeta,
        enrichedAt.isAcceptableOrUnknown(data['enriched_at']!, _enrichedAtMeta),
      );
    }
    if (data.containsKey('enrich_error')) {
      context.handle(
        _enrichErrorMeta,
        enrichError.isAcceptableOrUnknown(
          data['enrich_error']!,
          _enrichErrorMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {eventId};
  @override
  DerivedFactor map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DerivedFactor(
      eventId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}event_id'],
      )!,
      dayOfWeek: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}day_of_week'],
      ),
      season: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}season'],
      ),
      timeOfDayBucket: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}time_of_day_bucket'],
      ),
      daylightHours: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}daylight_hours'],
      ),
      sunriseUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}sunrise_utc'],
      ),
      sunsetUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}sunset_utc'],
      ),
      moonPhase: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}moon_phase'],
      ),
      moonIllumination: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}moon_illumination'],
      ),
      tempC: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}temp_c'],
      ),
      humidityPct: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}humidity_pct'],
      ),
      pressureHpa: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}pressure_hpa'],
      ),
      precipitationMm: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}precipitation_mm'],
      ),
      pressureDelta24h: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}pressure_delta24h'],
      ),
      pressureDelta48h: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}pressure_delta48h'],
      ),
      aqi: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}aqi'],
      ),
      enrichedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}enriched_at'],
      ),
      enrichError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}enrich_error'],
      ),
    );
  }

  @override
  $DerivedFactorsTable createAlias(String alias) {
    return $DerivedFactorsTable(attachedDatabase, alias);
  }
}

class DerivedFactor extends DataClass implements Insertable<DerivedFactor> {
  final String eventId;

  /// 0=Mon .. 6=Sun, local date of startedAt.
  final int? dayOfWeek;

  /// Meteorological season, hemisphere-aware.
  final String? season;

  /// morning / afternoon / evening / night (local).
  final String? timeOfDayBucket;
  final double? daylightHours;
  final DateTime? sunriseUtc;
  final DateTime? sunsetUtc;

  /// One of 8 named phases.
  final String? moonPhase;

  /// 0–1.
  final double? moonIllumination;
  final double? tempC;
  final double? humidityPct;
  final double? pressureHpa;
  final double? precipitationMm;
  final double? pressureDelta24h;
  final double? pressureDelta48h;
  final int? aqi;

  /// null / partial ⇒ row is in the enrichment retry queue.
  final DateTime? enrichedAt;

  /// Last failure reason, surfaced in UI.
  final String? enrichError;
  const DerivedFactor({
    required this.eventId,
    this.dayOfWeek,
    this.season,
    this.timeOfDayBucket,
    this.daylightHours,
    this.sunriseUtc,
    this.sunsetUtc,
    this.moonPhase,
    this.moonIllumination,
    this.tempC,
    this.humidityPct,
    this.pressureHpa,
    this.precipitationMm,
    this.pressureDelta24h,
    this.pressureDelta48h,
    this.aqi,
    this.enrichedAt,
    this.enrichError,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['event_id'] = Variable<String>(eventId);
    if (!nullToAbsent || dayOfWeek != null) {
      map['day_of_week'] = Variable<int>(dayOfWeek);
    }
    if (!nullToAbsent || season != null) {
      map['season'] = Variable<String>(season);
    }
    if (!nullToAbsent || timeOfDayBucket != null) {
      map['time_of_day_bucket'] = Variable<String>(timeOfDayBucket);
    }
    if (!nullToAbsent || daylightHours != null) {
      map['daylight_hours'] = Variable<double>(daylightHours);
    }
    if (!nullToAbsent || sunriseUtc != null) {
      map['sunrise_utc'] = Variable<DateTime>(sunriseUtc);
    }
    if (!nullToAbsent || sunsetUtc != null) {
      map['sunset_utc'] = Variable<DateTime>(sunsetUtc);
    }
    if (!nullToAbsent || moonPhase != null) {
      map['moon_phase'] = Variable<String>(moonPhase);
    }
    if (!nullToAbsent || moonIllumination != null) {
      map['moon_illumination'] = Variable<double>(moonIllumination);
    }
    if (!nullToAbsent || tempC != null) {
      map['temp_c'] = Variable<double>(tempC);
    }
    if (!nullToAbsent || humidityPct != null) {
      map['humidity_pct'] = Variable<double>(humidityPct);
    }
    if (!nullToAbsent || pressureHpa != null) {
      map['pressure_hpa'] = Variable<double>(pressureHpa);
    }
    if (!nullToAbsent || precipitationMm != null) {
      map['precipitation_mm'] = Variable<double>(precipitationMm);
    }
    if (!nullToAbsent || pressureDelta24h != null) {
      map['pressure_delta24h'] = Variable<double>(pressureDelta24h);
    }
    if (!nullToAbsent || pressureDelta48h != null) {
      map['pressure_delta48h'] = Variable<double>(pressureDelta48h);
    }
    if (!nullToAbsent || aqi != null) {
      map['aqi'] = Variable<int>(aqi);
    }
    if (!nullToAbsent || enrichedAt != null) {
      map['enriched_at'] = Variable<DateTime>(enrichedAt);
    }
    if (!nullToAbsent || enrichError != null) {
      map['enrich_error'] = Variable<String>(enrichError);
    }
    return map;
  }

  DerivedFactorsCompanion toCompanion(bool nullToAbsent) {
    return DerivedFactorsCompanion(
      eventId: Value(eventId),
      dayOfWeek: dayOfWeek == null && nullToAbsent
          ? const Value.absent()
          : Value(dayOfWeek),
      season: season == null && nullToAbsent
          ? const Value.absent()
          : Value(season),
      timeOfDayBucket: timeOfDayBucket == null && nullToAbsent
          ? const Value.absent()
          : Value(timeOfDayBucket),
      daylightHours: daylightHours == null && nullToAbsent
          ? const Value.absent()
          : Value(daylightHours),
      sunriseUtc: sunriseUtc == null && nullToAbsent
          ? const Value.absent()
          : Value(sunriseUtc),
      sunsetUtc: sunsetUtc == null && nullToAbsent
          ? const Value.absent()
          : Value(sunsetUtc),
      moonPhase: moonPhase == null && nullToAbsent
          ? const Value.absent()
          : Value(moonPhase),
      moonIllumination: moonIllumination == null && nullToAbsent
          ? const Value.absent()
          : Value(moonIllumination),
      tempC: tempC == null && nullToAbsent
          ? const Value.absent()
          : Value(tempC),
      humidityPct: humidityPct == null && nullToAbsent
          ? const Value.absent()
          : Value(humidityPct),
      pressureHpa: pressureHpa == null && nullToAbsent
          ? const Value.absent()
          : Value(pressureHpa),
      precipitationMm: precipitationMm == null && nullToAbsent
          ? const Value.absent()
          : Value(precipitationMm),
      pressureDelta24h: pressureDelta24h == null && nullToAbsent
          ? const Value.absent()
          : Value(pressureDelta24h),
      pressureDelta48h: pressureDelta48h == null && nullToAbsent
          ? const Value.absent()
          : Value(pressureDelta48h),
      aqi: aqi == null && nullToAbsent ? const Value.absent() : Value(aqi),
      enrichedAt: enrichedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(enrichedAt),
      enrichError: enrichError == null && nullToAbsent
          ? const Value.absent()
          : Value(enrichError),
    );
  }

  factory DerivedFactor.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DerivedFactor(
      eventId: serializer.fromJson<String>(json['eventId']),
      dayOfWeek: serializer.fromJson<int?>(json['dayOfWeek']),
      season: serializer.fromJson<String?>(json['season']),
      timeOfDayBucket: serializer.fromJson<String?>(json['timeOfDayBucket']),
      daylightHours: serializer.fromJson<double?>(json['daylightHours']),
      sunriseUtc: serializer.fromJson<DateTime?>(json['sunriseUtc']),
      sunsetUtc: serializer.fromJson<DateTime?>(json['sunsetUtc']),
      moonPhase: serializer.fromJson<String?>(json['moonPhase']),
      moonIllumination: serializer.fromJson<double?>(json['moonIllumination']),
      tempC: serializer.fromJson<double?>(json['tempC']),
      humidityPct: serializer.fromJson<double?>(json['humidityPct']),
      pressureHpa: serializer.fromJson<double?>(json['pressureHpa']),
      precipitationMm: serializer.fromJson<double?>(json['precipitationMm']),
      pressureDelta24h: serializer.fromJson<double?>(json['pressureDelta24h']),
      pressureDelta48h: serializer.fromJson<double?>(json['pressureDelta48h']),
      aqi: serializer.fromJson<int?>(json['aqi']),
      enrichedAt: serializer.fromJson<DateTime?>(json['enrichedAt']),
      enrichError: serializer.fromJson<String?>(json['enrichError']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'eventId': serializer.toJson<String>(eventId),
      'dayOfWeek': serializer.toJson<int?>(dayOfWeek),
      'season': serializer.toJson<String?>(season),
      'timeOfDayBucket': serializer.toJson<String?>(timeOfDayBucket),
      'daylightHours': serializer.toJson<double?>(daylightHours),
      'sunriseUtc': serializer.toJson<DateTime?>(sunriseUtc),
      'sunsetUtc': serializer.toJson<DateTime?>(sunsetUtc),
      'moonPhase': serializer.toJson<String?>(moonPhase),
      'moonIllumination': serializer.toJson<double?>(moonIllumination),
      'tempC': serializer.toJson<double?>(tempC),
      'humidityPct': serializer.toJson<double?>(humidityPct),
      'pressureHpa': serializer.toJson<double?>(pressureHpa),
      'precipitationMm': serializer.toJson<double?>(precipitationMm),
      'pressureDelta24h': serializer.toJson<double?>(pressureDelta24h),
      'pressureDelta48h': serializer.toJson<double?>(pressureDelta48h),
      'aqi': serializer.toJson<int?>(aqi),
      'enrichedAt': serializer.toJson<DateTime?>(enrichedAt),
      'enrichError': serializer.toJson<String?>(enrichError),
    };
  }

  DerivedFactor copyWith({
    String? eventId,
    Value<int?> dayOfWeek = const Value.absent(),
    Value<String?> season = const Value.absent(),
    Value<String?> timeOfDayBucket = const Value.absent(),
    Value<double?> daylightHours = const Value.absent(),
    Value<DateTime?> sunriseUtc = const Value.absent(),
    Value<DateTime?> sunsetUtc = const Value.absent(),
    Value<String?> moonPhase = const Value.absent(),
    Value<double?> moonIllumination = const Value.absent(),
    Value<double?> tempC = const Value.absent(),
    Value<double?> humidityPct = const Value.absent(),
    Value<double?> pressureHpa = const Value.absent(),
    Value<double?> precipitationMm = const Value.absent(),
    Value<double?> pressureDelta24h = const Value.absent(),
    Value<double?> pressureDelta48h = const Value.absent(),
    Value<int?> aqi = const Value.absent(),
    Value<DateTime?> enrichedAt = const Value.absent(),
    Value<String?> enrichError = const Value.absent(),
  }) => DerivedFactor(
    eventId: eventId ?? this.eventId,
    dayOfWeek: dayOfWeek.present ? dayOfWeek.value : this.dayOfWeek,
    season: season.present ? season.value : this.season,
    timeOfDayBucket: timeOfDayBucket.present
        ? timeOfDayBucket.value
        : this.timeOfDayBucket,
    daylightHours: daylightHours.present
        ? daylightHours.value
        : this.daylightHours,
    sunriseUtc: sunriseUtc.present ? sunriseUtc.value : this.sunriseUtc,
    sunsetUtc: sunsetUtc.present ? sunsetUtc.value : this.sunsetUtc,
    moonPhase: moonPhase.present ? moonPhase.value : this.moonPhase,
    moonIllumination: moonIllumination.present
        ? moonIllumination.value
        : this.moonIllumination,
    tempC: tempC.present ? tempC.value : this.tempC,
    humidityPct: humidityPct.present ? humidityPct.value : this.humidityPct,
    pressureHpa: pressureHpa.present ? pressureHpa.value : this.pressureHpa,
    precipitationMm: precipitationMm.present
        ? precipitationMm.value
        : this.precipitationMm,
    pressureDelta24h: pressureDelta24h.present
        ? pressureDelta24h.value
        : this.pressureDelta24h,
    pressureDelta48h: pressureDelta48h.present
        ? pressureDelta48h.value
        : this.pressureDelta48h,
    aqi: aqi.present ? aqi.value : this.aqi,
    enrichedAt: enrichedAt.present ? enrichedAt.value : this.enrichedAt,
    enrichError: enrichError.present ? enrichError.value : this.enrichError,
  );
  DerivedFactor copyWithCompanion(DerivedFactorsCompanion data) {
    return DerivedFactor(
      eventId: data.eventId.present ? data.eventId.value : this.eventId,
      dayOfWeek: data.dayOfWeek.present ? data.dayOfWeek.value : this.dayOfWeek,
      season: data.season.present ? data.season.value : this.season,
      timeOfDayBucket: data.timeOfDayBucket.present
          ? data.timeOfDayBucket.value
          : this.timeOfDayBucket,
      daylightHours: data.daylightHours.present
          ? data.daylightHours.value
          : this.daylightHours,
      sunriseUtc: data.sunriseUtc.present
          ? data.sunriseUtc.value
          : this.sunriseUtc,
      sunsetUtc: data.sunsetUtc.present ? data.sunsetUtc.value : this.sunsetUtc,
      moonPhase: data.moonPhase.present ? data.moonPhase.value : this.moonPhase,
      moonIllumination: data.moonIllumination.present
          ? data.moonIllumination.value
          : this.moonIllumination,
      tempC: data.tempC.present ? data.tempC.value : this.tempC,
      humidityPct: data.humidityPct.present
          ? data.humidityPct.value
          : this.humidityPct,
      pressureHpa: data.pressureHpa.present
          ? data.pressureHpa.value
          : this.pressureHpa,
      precipitationMm: data.precipitationMm.present
          ? data.precipitationMm.value
          : this.precipitationMm,
      pressureDelta24h: data.pressureDelta24h.present
          ? data.pressureDelta24h.value
          : this.pressureDelta24h,
      pressureDelta48h: data.pressureDelta48h.present
          ? data.pressureDelta48h.value
          : this.pressureDelta48h,
      aqi: data.aqi.present ? data.aqi.value : this.aqi,
      enrichedAt: data.enrichedAt.present
          ? data.enrichedAt.value
          : this.enrichedAt,
      enrichError: data.enrichError.present
          ? data.enrichError.value
          : this.enrichError,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DerivedFactor(')
          ..write('eventId: $eventId, ')
          ..write('dayOfWeek: $dayOfWeek, ')
          ..write('season: $season, ')
          ..write('timeOfDayBucket: $timeOfDayBucket, ')
          ..write('daylightHours: $daylightHours, ')
          ..write('sunriseUtc: $sunriseUtc, ')
          ..write('sunsetUtc: $sunsetUtc, ')
          ..write('moonPhase: $moonPhase, ')
          ..write('moonIllumination: $moonIllumination, ')
          ..write('tempC: $tempC, ')
          ..write('humidityPct: $humidityPct, ')
          ..write('pressureHpa: $pressureHpa, ')
          ..write('precipitationMm: $precipitationMm, ')
          ..write('pressureDelta24h: $pressureDelta24h, ')
          ..write('pressureDelta48h: $pressureDelta48h, ')
          ..write('aqi: $aqi, ')
          ..write('enrichedAt: $enrichedAt, ')
          ..write('enrichError: $enrichError')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    eventId,
    dayOfWeek,
    season,
    timeOfDayBucket,
    daylightHours,
    sunriseUtc,
    sunsetUtc,
    moonPhase,
    moonIllumination,
    tempC,
    humidityPct,
    pressureHpa,
    precipitationMm,
    pressureDelta24h,
    pressureDelta48h,
    aqi,
    enrichedAt,
    enrichError,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DerivedFactor &&
          other.eventId == this.eventId &&
          other.dayOfWeek == this.dayOfWeek &&
          other.season == this.season &&
          other.timeOfDayBucket == this.timeOfDayBucket &&
          other.daylightHours == this.daylightHours &&
          other.sunriseUtc == this.sunriseUtc &&
          other.sunsetUtc == this.sunsetUtc &&
          other.moonPhase == this.moonPhase &&
          other.moonIllumination == this.moonIllumination &&
          other.tempC == this.tempC &&
          other.humidityPct == this.humidityPct &&
          other.pressureHpa == this.pressureHpa &&
          other.precipitationMm == this.precipitationMm &&
          other.pressureDelta24h == this.pressureDelta24h &&
          other.pressureDelta48h == this.pressureDelta48h &&
          other.aqi == this.aqi &&
          other.enrichedAt == this.enrichedAt &&
          other.enrichError == this.enrichError);
}

class DerivedFactorsCompanion extends UpdateCompanion<DerivedFactor> {
  final Value<String> eventId;
  final Value<int?> dayOfWeek;
  final Value<String?> season;
  final Value<String?> timeOfDayBucket;
  final Value<double?> daylightHours;
  final Value<DateTime?> sunriseUtc;
  final Value<DateTime?> sunsetUtc;
  final Value<String?> moonPhase;
  final Value<double?> moonIllumination;
  final Value<double?> tempC;
  final Value<double?> humidityPct;
  final Value<double?> pressureHpa;
  final Value<double?> precipitationMm;
  final Value<double?> pressureDelta24h;
  final Value<double?> pressureDelta48h;
  final Value<int?> aqi;
  final Value<DateTime?> enrichedAt;
  final Value<String?> enrichError;
  final Value<int> rowid;
  const DerivedFactorsCompanion({
    this.eventId = const Value.absent(),
    this.dayOfWeek = const Value.absent(),
    this.season = const Value.absent(),
    this.timeOfDayBucket = const Value.absent(),
    this.daylightHours = const Value.absent(),
    this.sunriseUtc = const Value.absent(),
    this.sunsetUtc = const Value.absent(),
    this.moonPhase = const Value.absent(),
    this.moonIllumination = const Value.absent(),
    this.tempC = const Value.absent(),
    this.humidityPct = const Value.absent(),
    this.pressureHpa = const Value.absent(),
    this.precipitationMm = const Value.absent(),
    this.pressureDelta24h = const Value.absent(),
    this.pressureDelta48h = const Value.absent(),
    this.aqi = const Value.absent(),
    this.enrichedAt = const Value.absent(),
    this.enrichError = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DerivedFactorsCompanion.insert({
    required String eventId,
    this.dayOfWeek = const Value.absent(),
    this.season = const Value.absent(),
    this.timeOfDayBucket = const Value.absent(),
    this.daylightHours = const Value.absent(),
    this.sunriseUtc = const Value.absent(),
    this.sunsetUtc = const Value.absent(),
    this.moonPhase = const Value.absent(),
    this.moonIllumination = const Value.absent(),
    this.tempC = const Value.absent(),
    this.humidityPct = const Value.absent(),
    this.pressureHpa = const Value.absent(),
    this.precipitationMm = const Value.absent(),
    this.pressureDelta24h = const Value.absent(),
    this.pressureDelta48h = const Value.absent(),
    this.aqi = const Value.absent(),
    this.enrichedAt = const Value.absent(),
    this.enrichError = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : eventId = Value(eventId);
  static Insertable<DerivedFactor> custom({
    Expression<String>? eventId,
    Expression<int>? dayOfWeek,
    Expression<String>? season,
    Expression<String>? timeOfDayBucket,
    Expression<double>? daylightHours,
    Expression<DateTime>? sunriseUtc,
    Expression<DateTime>? sunsetUtc,
    Expression<String>? moonPhase,
    Expression<double>? moonIllumination,
    Expression<double>? tempC,
    Expression<double>? humidityPct,
    Expression<double>? pressureHpa,
    Expression<double>? precipitationMm,
    Expression<double>? pressureDelta24h,
    Expression<double>? pressureDelta48h,
    Expression<int>? aqi,
    Expression<DateTime>? enrichedAt,
    Expression<String>? enrichError,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (eventId != null) 'event_id': eventId,
      if (dayOfWeek != null) 'day_of_week': dayOfWeek,
      if (season != null) 'season': season,
      if (timeOfDayBucket != null) 'time_of_day_bucket': timeOfDayBucket,
      if (daylightHours != null) 'daylight_hours': daylightHours,
      if (sunriseUtc != null) 'sunrise_utc': sunriseUtc,
      if (sunsetUtc != null) 'sunset_utc': sunsetUtc,
      if (moonPhase != null) 'moon_phase': moonPhase,
      if (moonIllumination != null) 'moon_illumination': moonIllumination,
      if (tempC != null) 'temp_c': tempC,
      if (humidityPct != null) 'humidity_pct': humidityPct,
      if (pressureHpa != null) 'pressure_hpa': pressureHpa,
      if (precipitationMm != null) 'precipitation_mm': precipitationMm,
      if (pressureDelta24h != null) 'pressure_delta24h': pressureDelta24h,
      if (pressureDelta48h != null) 'pressure_delta48h': pressureDelta48h,
      if (aqi != null) 'aqi': aqi,
      if (enrichedAt != null) 'enriched_at': enrichedAt,
      if (enrichError != null) 'enrich_error': enrichError,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DerivedFactorsCompanion copyWith({
    Value<String>? eventId,
    Value<int?>? dayOfWeek,
    Value<String?>? season,
    Value<String?>? timeOfDayBucket,
    Value<double?>? daylightHours,
    Value<DateTime?>? sunriseUtc,
    Value<DateTime?>? sunsetUtc,
    Value<String?>? moonPhase,
    Value<double?>? moonIllumination,
    Value<double?>? tempC,
    Value<double?>? humidityPct,
    Value<double?>? pressureHpa,
    Value<double?>? precipitationMm,
    Value<double?>? pressureDelta24h,
    Value<double?>? pressureDelta48h,
    Value<int?>? aqi,
    Value<DateTime?>? enrichedAt,
    Value<String?>? enrichError,
    Value<int>? rowid,
  }) {
    return DerivedFactorsCompanion(
      eventId: eventId ?? this.eventId,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      season: season ?? this.season,
      timeOfDayBucket: timeOfDayBucket ?? this.timeOfDayBucket,
      daylightHours: daylightHours ?? this.daylightHours,
      sunriseUtc: sunriseUtc ?? this.sunriseUtc,
      sunsetUtc: sunsetUtc ?? this.sunsetUtc,
      moonPhase: moonPhase ?? this.moonPhase,
      moonIllumination: moonIllumination ?? this.moonIllumination,
      tempC: tempC ?? this.tempC,
      humidityPct: humidityPct ?? this.humidityPct,
      pressureHpa: pressureHpa ?? this.pressureHpa,
      precipitationMm: precipitationMm ?? this.precipitationMm,
      pressureDelta24h: pressureDelta24h ?? this.pressureDelta24h,
      pressureDelta48h: pressureDelta48h ?? this.pressureDelta48h,
      aqi: aqi ?? this.aqi,
      enrichedAt: enrichedAt ?? this.enrichedAt,
      enrichError: enrichError ?? this.enrichError,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (eventId.present) {
      map['event_id'] = Variable<String>(eventId.value);
    }
    if (dayOfWeek.present) {
      map['day_of_week'] = Variable<int>(dayOfWeek.value);
    }
    if (season.present) {
      map['season'] = Variable<String>(season.value);
    }
    if (timeOfDayBucket.present) {
      map['time_of_day_bucket'] = Variable<String>(timeOfDayBucket.value);
    }
    if (daylightHours.present) {
      map['daylight_hours'] = Variable<double>(daylightHours.value);
    }
    if (sunriseUtc.present) {
      map['sunrise_utc'] = Variable<DateTime>(sunriseUtc.value);
    }
    if (sunsetUtc.present) {
      map['sunset_utc'] = Variable<DateTime>(sunsetUtc.value);
    }
    if (moonPhase.present) {
      map['moon_phase'] = Variable<String>(moonPhase.value);
    }
    if (moonIllumination.present) {
      map['moon_illumination'] = Variable<double>(moonIllumination.value);
    }
    if (tempC.present) {
      map['temp_c'] = Variable<double>(tempC.value);
    }
    if (humidityPct.present) {
      map['humidity_pct'] = Variable<double>(humidityPct.value);
    }
    if (pressureHpa.present) {
      map['pressure_hpa'] = Variable<double>(pressureHpa.value);
    }
    if (precipitationMm.present) {
      map['precipitation_mm'] = Variable<double>(precipitationMm.value);
    }
    if (pressureDelta24h.present) {
      map['pressure_delta24h'] = Variable<double>(pressureDelta24h.value);
    }
    if (pressureDelta48h.present) {
      map['pressure_delta48h'] = Variable<double>(pressureDelta48h.value);
    }
    if (aqi.present) {
      map['aqi'] = Variable<int>(aqi.value);
    }
    if (enrichedAt.present) {
      map['enriched_at'] = Variable<DateTime>(enrichedAt.value);
    }
    if (enrichError.present) {
      map['enrich_error'] = Variable<String>(enrichError.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DerivedFactorsCompanion(')
          ..write('eventId: $eventId, ')
          ..write('dayOfWeek: $dayOfWeek, ')
          ..write('season: $season, ')
          ..write('timeOfDayBucket: $timeOfDayBucket, ')
          ..write('daylightHours: $daylightHours, ')
          ..write('sunriseUtc: $sunriseUtc, ')
          ..write('sunsetUtc: $sunsetUtc, ')
          ..write('moonPhase: $moonPhase, ')
          ..write('moonIllumination: $moonIllumination, ')
          ..write('tempC: $tempC, ')
          ..write('humidityPct: $humidityPct, ')
          ..write('pressureHpa: $pressureHpa, ')
          ..write('precipitationMm: $precipitationMm, ')
          ..write('pressureDelta24h: $pressureDelta24h, ')
          ..write('pressureDelta48h: $pressureDelta48h, ')
          ..write('aqi: $aqi, ')
          ..write('enrichedAt: $enrichedAt, ')
          ..write('enrichError: $enrichError, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AppSettingsTable extends AppSettings
    with TableInfo<$AppSettingsTable, AppSetting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppSetting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  AppSetting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppSetting(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $AppSettingsTable createAlias(String alias) {
    return $AppSettingsTable(attachedDatabase, alias);
  }
}

class AppSetting extends DataClass implements Insertable<AppSetting> {
  final String key;
  final String value;
  const AppSetting({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  AppSettingsCompanion toCompanion(bool nullToAbsent) {
    return AppSettingsCompanion(key: Value(key), value: Value(value));
  }

  factory AppSetting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppSetting(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  AppSetting copyWith({String? key, String? value}) =>
      AppSetting(key: key ?? this.key, value: value ?? this.value);
  AppSetting copyWithCompanion(AppSettingsCompanion data) {
    return AppSetting(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppSetting(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppSetting &&
          other.key == this.key &&
          other.value == this.value);
}

class AppSettingsCompanion extends UpdateCompanion<AppSetting> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const AppSettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppSettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<AppSetting> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppSettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return AppSettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $VocabulariesTable extends Vocabularies
    with TableInfo<$VocabulariesTable, Vocabulary> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $VocabulariesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sortMeta = const VerificationMeta('sort');
  @override
  late final GeneratedColumn<int> sort = GeneratedColumn<int>(
    'sort',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [kind, value, sort];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'vocabularies';
  @override
  VerificationContext validateIntegrity(
    Insertable<Vocabulary> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    if (data.containsKey('sort')) {
      context.handle(
        _sortMeta,
        sort.isAcceptableOrUnknown(data['sort']!, _sortMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {kind, value};
  @override
  Vocabulary map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Vocabulary(
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
      sort: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort'],
      )!,
    );
  }

  @override
  $VocabulariesTable createAlias(String alias) {
    return $VocabulariesTable(attachedDatabase, alias);
  }
}

class Vocabulary extends DataClass implements Insertable<Vocabulary> {
  final String kind;
  final String value;
  final int sort;
  const Vocabulary({
    required this.kind,
    required this.value,
    required this.sort,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['kind'] = Variable<String>(kind);
    map['value'] = Variable<String>(value);
    map['sort'] = Variable<int>(sort);
    return map;
  }

  VocabulariesCompanion toCompanion(bool nullToAbsent) {
    return VocabulariesCompanion(
      kind: Value(kind),
      value: Value(value),
      sort: Value(sort),
    );
  }

  factory Vocabulary.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Vocabulary(
      kind: serializer.fromJson<String>(json['kind']),
      value: serializer.fromJson<String>(json['value']),
      sort: serializer.fromJson<int>(json['sort']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'kind': serializer.toJson<String>(kind),
      'value': serializer.toJson<String>(value),
      'sort': serializer.toJson<int>(sort),
    };
  }

  Vocabulary copyWith({String? kind, String? value, int? sort}) => Vocabulary(
    kind: kind ?? this.kind,
    value: value ?? this.value,
    sort: sort ?? this.sort,
  );
  Vocabulary copyWithCompanion(VocabulariesCompanion data) {
    return Vocabulary(
      kind: data.kind.present ? data.kind.value : this.kind,
      value: data.value.present ? data.value.value : this.value,
      sort: data.sort.present ? data.sort.value : this.sort,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Vocabulary(')
          ..write('kind: $kind, ')
          ..write('value: $value, ')
          ..write('sort: $sort')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(kind, value, sort);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Vocabulary &&
          other.kind == this.kind &&
          other.value == this.value &&
          other.sort == this.sort);
}

class VocabulariesCompanion extends UpdateCompanion<Vocabulary> {
  final Value<String> kind;
  final Value<String> value;
  final Value<int> sort;
  final Value<int> rowid;
  const VocabulariesCompanion({
    this.kind = const Value.absent(),
    this.value = const Value.absent(),
    this.sort = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  VocabulariesCompanion.insert({
    required String kind,
    required String value,
    this.sort = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : kind = Value(kind),
       value = Value(value);
  static Insertable<Vocabulary> custom({
    Expression<String>? kind,
    Expression<String>? value,
    Expression<int>? sort,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (kind != null) 'kind': kind,
      if (value != null) 'value': value,
      if (sort != null) 'sort': sort,
      if (rowid != null) 'rowid': rowid,
    });
  }

  VocabulariesCompanion copyWith({
    Value<String>? kind,
    Value<String>? value,
    Value<int>? sort,
    Value<int>? rowid,
  }) {
    return VocabulariesCompanion(
      kind: kind ?? this.kind,
      value: value ?? this.value,
      sort: sort ?? this.sort,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (sort.present) {
      map['sort'] = Variable<int>(sort.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('VocabulariesCompanion(')
          ..write('kind: $kind, ')
          ..write('value: $value, ')
          ..write('sort: $sort, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$MegrimDatabase extends GeneratedDatabase {
  _$MegrimDatabase(QueryExecutor e) : super(e);
  $MegrimDatabaseManager get managers => $MegrimDatabaseManager(this);
  late final $MigraineEventsTable migraineEvents = $MigraineEventsTable(this);
  late final $DerivedFactorsTable derivedFactors = $DerivedFactorsTable(this);
  late final $AppSettingsTable appSettings = $AppSettingsTable(this);
  late final $VocabulariesTable vocabularies = $VocabulariesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    migraineEvents,
    derivedFactors,
    appSettings,
    vocabularies,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'migraine_events',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('derived_factors', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$MigraineEventsTableCreateCompanionBuilder =
    MigraineEventsCompanion Function({
      required String id,
      required DateTime startedAt,
      Value<DateTime?> endedAt,
      Value<int?> severity,
      Value<String?> locationHead,
      Value<bool?> auraPresent,
      Value<String?> auraDescription,
      Value<String?> medsTaken,
      Value<String?> triggersSuspected,
      Value<double?> sleepHoursPrior,
      Value<int?> stressLevel,
      Value<String?> foodsNotable,
      Value<String?> notes,
      Value<double?> geoLat,
      Value<double?> geoLon,
      Value<String?> geoLabel,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$MigraineEventsTableUpdateCompanionBuilder =
    MigraineEventsCompanion Function({
      Value<String> id,
      Value<DateTime> startedAt,
      Value<DateTime?> endedAt,
      Value<int?> severity,
      Value<String?> locationHead,
      Value<bool?> auraPresent,
      Value<String?> auraDescription,
      Value<String?> medsTaken,
      Value<String?> triggersSuspected,
      Value<double?> sleepHoursPrior,
      Value<int?> stressLevel,
      Value<String?> foodsNotable,
      Value<String?> notes,
      Value<double?> geoLat,
      Value<double?> geoLon,
      Value<String?> geoLabel,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$MigraineEventsTableReferences
    extends
        BaseReferences<_$MegrimDatabase, $MigraineEventsTable, MigraineEvent> {
  $$MigraineEventsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$DerivedFactorsTable, List<DerivedFactor>>
  _derivedFactorsRefsTable(_$MegrimDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.derivedFactors,
        aliasName: 'migraine_events__id__derived_factors__event_id',
      );

  $$DerivedFactorsTableProcessedTableManager get derivedFactorsRefs {
    final manager = $$DerivedFactorsTableTableManager(
      $_db,
      $_db.derivedFactors,
    ).filter((f) => f.eventId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_derivedFactorsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$MigraineEventsTableFilterComposer
    extends Composer<_$MegrimDatabase, $MigraineEventsTable> {
  $$MigraineEventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get severity => $composableBuilder(
    column: $table.severity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get locationHead => $composableBuilder(
    column: $table.locationHead,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get auraPresent => $composableBuilder(
    column: $table.auraPresent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get auraDescription => $composableBuilder(
    column: $table.auraDescription,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get medsTaken => $composableBuilder(
    column: $table.medsTaken,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get triggersSuspected => $composableBuilder(
    column: $table.triggersSuspected,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get sleepHoursPrior => $composableBuilder(
    column: $table.sleepHoursPrior,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get stressLevel => $composableBuilder(
    column: $table.stressLevel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get foodsNotable => $composableBuilder(
    column: $table.foodsNotable,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get geoLat => $composableBuilder(
    column: $table.geoLat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get geoLon => $composableBuilder(
    column: $table.geoLon,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get geoLabel => $composableBuilder(
    column: $table.geoLabel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> derivedFactorsRefs(
    Expression<bool> Function($$DerivedFactorsTableFilterComposer f) f,
  ) {
    final $$DerivedFactorsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.derivedFactors,
      getReferencedColumn: (t) => t.eventId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DerivedFactorsTableFilterComposer(
            $db: $db,
            $table: $db.derivedFactors,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MigraineEventsTableOrderingComposer
    extends Composer<_$MegrimDatabase, $MigraineEventsTable> {
  $$MigraineEventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get severity => $composableBuilder(
    column: $table.severity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get locationHead => $composableBuilder(
    column: $table.locationHead,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get auraPresent => $composableBuilder(
    column: $table.auraPresent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get auraDescription => $composableBuilder(
    column: $table.auraDescription,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get medsTaken => $composableBuilder(
    column: $table.medsTaken,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get triggersSuspected => $composableBuilder(
    column: $table.triggersSuspected,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get sleepHoursPrior => $composableBuilder(
    column: $table.sleepHoursPrior,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get stressLevel => $composableBuilder(
    column: $table.stressLevel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get foodsNotable => $composableBuilder(
    column: $table.foodsNotable,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get geoLat => $composableBuilder(
    column: $table.geoLat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get geoLon => $composableBuilder(
    column: $table.geoLon,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get geoLabel => $composableBuilder(
    column: $table.geoLabel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MigraineEventsTableAnnotationComposer
    extends Composer<_$MegrimDatabase, $MigraineEventsTable> {
  $$MigraineEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get endedAt =>
      $composableBuilder(column: $table.endedAt, builder: (column) => column);

  GeneratedColumn<int> get severity =>
      $composableBuilder(column: $table.severity, builder: (column) => column);

  GeneratedColumn<String> get locationHead => $composableBuilder(
    column: $table.locationHead,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get auraPresent => $composableBuilder(
    column: $table.auraPresent,
    builder: (column) => column,
  );

  GeneratedColumn<String> get auraDescription => $composableBuilder(
    column: $table.auraDescription,
    builder: (column) => column,
  );

  GeneratedColumn<String> get medsTaken =>
      $composableBuilder(column: $table.medsTaken, builder: (column) => column);

  GeneratedColumn<String> get triggersSuspected => $composableBuilder(
    column: $table.triggersSuspected,
    builder: (column) => column,
  );

  GeneratedColumn<double> get sleepHoursPrior => $composableBuilder(
    column: $table.sleepHoursPrior,
    builder: (column) => column,
  );

  GeneratedColumn<int> get stressLevel => $composableBuilder(
    column: $table.stressLevel,
    builder: (column) => column,
  );

  GeneratedColumn<String> get foodsNotable => $composableBuilder(
    column: $table.foodsNotable,
    builder: (column) => column,
  );

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<double> get geoLat =>
      $composableBuilder(column: $table.geoLat, builder: (column) => column);

  GeneratedColumn<double> get geoLon =>
      $composableBuilder(column: $table.geoLon, builder: (column) => column);

  GeneratedColumn<String> get geoLabel =>
      $composableBuilder(column: $table.geoLabel, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> derivedFactorsRefs<T extends Object>(
    Expression<T> Function($$DerivedFactorsTableAnnotationComposer a) f,
  ) {
    final $$DerivedFactorsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.derivedFactors,
      getReferencedColumn: (t) => t.eventId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DerivedFactorsTableAnnotationComposer(
            $db: $db,
            $table: $db.derivedFactors,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MigraineEventsTableTableManager
    extends
        RootTableManager<
          _$MegrimDatabase,
          $MigraineEventsTable,
          MigraineEvent,
          $$MigraineEventsTableFilterComposer,
          $$MigraineEventsTableOrderingComposer,
          $$MigraineEventsTableAnnotationComposer,
          $$MigraineEventsTableCreateCompanionBuilder,
          $$MigraineEventsTableUpdateCompanionBuilder,
          (MigraineEvent, $$MigraineEventsTableReferences),
          MigraineEvent,
          PrefetchHooks Function({bool derivedFactorsRefs})
        > {
  $$MigraineEventsTableTableManager(
    _$MegrimDatabase db,
    $MigraineEventsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MigraineEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MigraineEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MigraineEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<DateTime?> endedAt = const Value.absent(),
                Value<int?> severity = const Value.absent(),
                Value<String?> locationHead = const Value.absent(),
                Value<bool?> auraPresent = const Value.absent(),
                Value<String?> auraDescription = const Value.absent(),
                Value<String?> medsTaken = const Value.absent(),
                Value<String?> triggersSuspected = const Value.absent(),
                Value<double?> sleepHoursPrior = const Value.absent(),
                Value<int?> stressLevel = const Value.absent(),
                Value<String?> foodsNotable = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<double?> geoLat = const Value.absent(),
                Value<double?> geoLon = const Value.absent(),
                Value<String?> geoLabel = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MigraineEventsCompanion(
                id: id,
                startedAt: startedAt,
                endedAt: endedAt,
                severity: severity,
                locationHead: locationHead,
                auraPresent: auraPresent,
                auraDescription: auraDescription,
                medsTaken: medsTaken,
                triggersSuspected: triggersSuspected,
                sleepHoursPrior: sleepHoursPrior,
                stressLevel: stressLevel,
                foodsNotable: foodsNotable,
                notes: notes,
                geoLat: geoLat,
                geoLon: geoLon,
                geoLabel: geoLabel,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required DateTime startedAt,
                Value<DateTime?> endedAt = const Value.absent(),
                Value<int?> severity = const Value.absent(),
                Value<String?> locationHead = const Value.absent(),
                Value<bool?> auraPresent = const Value.absent(),
                Value<String?> auraDescription = const Value.absent(),
                Value<String?> medsTaken = const Value.absent(),
                Value<String?> triggersSuspected = const Value.absent(),
                Value<double?> sleepHoursPrior = const Value.absent(),
                Value<int?> stressLevel = const Value.absent(),
                Value<String?> foodsNotable = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<double?> geoLat = const Value.absent(),
                Value<double?> geoLon = const Value.absent(),
                Value<String?> geoLabel = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => MigraineEventsCompanion.insert(
                id: id,
                startedAt: startedAt,
                endedAt: endedAt,
                severity: severity,
                locationHead: locationHead,
                auraPresent: auraPresent,
                auraDescription: auraDescription,
                medsTaken: medsTaken,
                triggersSuspected: triggersSuspected,
                sleepHoursPrior: sleepHoursPrior,
                stressLevel: stressLevel,
                foodsNotable: foodsNotable,
                notes: notes,
                geoLat: geoLat,
                geoLon: geoLon,
                geoLabel: geoLabel,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$MigraineEventsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({derivedFactorsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (derivedFactorsRefs) db.derivedFactors,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (derivedFactorsRefs)
                    await $_getPrefetchedData<
                      MigraineEvent,
                      $MigraineEventsTable,
                      DerivedFactor
                    >(
                      currentTable: table,
                      referencedTable: $$MigraineEventsTableReferences
                          ._derivedFactorsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$MigraineEventsTableReferences(
                            db,
                            table,
                            p0,
                          ).derivedFactorsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.eventId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$MigraineEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$MegrimDatabase,
      $MigraineEventsTable,
      MigraineEvent,
      $$MigraineEventsTableFilterComposer,
      $$MigraineEventsTableOrderingComposer,
      $$MigraineEventsTableAnnotationComposer,
      $$MigraineEventsTableCreateCompanionBuilder,
      $$MigraineEventsTableUpdateCompanionBuilder,
      (MigraineEvent, $$MigraineEventsTableReferences),
      MigraineEvent,
      PrefetchHooks Function({bool derivedFactorsRefs})
    >;
typedef $$DerivedFactorsTableCreateCompanionBuilder =
    DerivedFactorsCompanion Function({
      required String eventId,
      Value<int?> dayOfWeek,
      Value<String?> season,
      Value<String?> timeOfDayBucket,
      Value<double?> daylightHours,
      Value<DateTime?> sunriseUtc,
      Value<DateTime?> sunsetUtc,
      Value<String?> moonPhase,
      Value<double?> moonIllumination,
      Value<double?> tempC,
      Value<double?> humidityPct,
      Value<double?> pressureHpa,
      Value<double?> precipitationMm,
      Value<double?> pressureDelta24h,
      Value<double?> pressureDelta48h,
      Value<int?> aqi,
      Value<DateTime?> enrichedAt,
      Value<String?> enrichError,
      Value<int> rowid,
    });
typedef $$DerivedFactorsTableUpdateCompanionBuilder =
    DerivedFactorsCompanion Function({
      Value<String> eventId,
      Value<int?> dayOfWeek,
      Value<String?> season,
      Value<String?> timeOfDayBucket,
      Value<double?> daylightHours,
      Value<DateTime?> sunriseUtc,
      Value<DateTime?> sunsetUtc,
      Value<String?> moonPhase,
      Value<double?> moonIllumination,
      Value<double?> tempC,
      Value<double?> humidityPct,
      Value<double?> pressureHpa,
      Value<double?> precipitationMm,
      Value<double?> pressureDelta24h,
      Value<double?> pressureDelta48h,
      Value<int?> aqi,
      Value<DateTime?> enrichedAt,
      Value<String?> enrichError,
      Value<int> rowid,
    });

final class $$DerivedFactorsTableReferences
    extends
        BaseReferences<_$MegrimDatabase, $DerivedFactorsTable, DerivedFactor> {
  $$DerivedFactorsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $MigraineEventsTable _eventIdTable(_$MegrimDatabase db) => db
      .migraineEvents
      .createAlias('derived_factors__event_id__migraine_events__id');

  $$MigraineEventsTableProcessedTableManager get eventId {
    final $_column = $_itemColumn<String>('event_id')!;

    final manager = $$MigraineEventsTableTableManager(
      $_db,
      $_db.migraineEvents,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_eventIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$DerivedFactorsTableFilterComposer
    extends Composer<_$MegrimDatabase, $DerivedFactorsTable> {
  $$DerivedFactorsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get dayOfWeek => $composableBuilder(
    column: $table.dayOfWeek,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get season => $composableBuilder(
    column: $table.season,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get timeOfDayBucket => $composableBuilder(
    column: $table.timeOfDayBucket,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get daylightHours => $composableBuilder(
    column: $table.daylightHours,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get sunriseUtc => $composableBuilder(
    column: $table.sunriseUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get sunsetUtc => $composableBuilder(
    column: $table.sunsetUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get moonPhase => $composableBuilder(
    column: $table.moonPhase,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get moonIllumination => $composableBuilder(
    column: $table.moonIllumination,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get tempC => $composableBuilder(
    column: $table.tempC,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get humidityPct => $composableBuilder(
    column: $table.humidityPct,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get pressureHpa => $composableBuilder(
    column: $table.pressureHpa,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get precipitationMm => $composableBuilder(
    column: $table.precipitationMm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get pressureDelta24h => $composableBuilder(
    column: $table.pressureDelta24h,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get pressureDelta48h => $composableBuilder(
    column: $table.pressureDelta48h,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get aqi => $composableBuilder(
    column: $table.aqi,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get enrichedAt => $composableBuilder(
    column: $table.enrichedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get enrichError => $composableBuilder(
    column: $table.enrichError,
    builder: (column) => ColumnFilters(column),
  );

  $$MigraineEventsTableFilterComposer get eventId {
    final $$MigraineEventsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.eventId,
      referencedTable: $db.migraineEvents,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MigraineEventsTableFilterComposer(
            $db: $db,
            $table: $db.migraineEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DerivedFactorsTableOrderingComposer
    extends Composer<_$MegrimDatabase, $DerivedFactorsTable> {
  $$DerivedFactorsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get dayOfWeek => $composableBuilder(
    column: $table.dayOfWeek,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get season => $composableBuilder(
    column: $table.season,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get timeOfDayBucket => $composableBuilder(
    column: $table.timeOfDayBucket,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get daylightHours => $composableBuilder(
    column: $table.daylightHours,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get sunriseUtc => $composableBuilder(
    column: $table.sunriseUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get sunsetUtc => $composableBuilder(
    column: $table.sunsetUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get moonPhase => $composableBuilder(
    column: $table.moonPhase,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get moonIllumination => $composableBuilder(
    column: $table.moonIllumination,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get tempC => $composableBuilder(
    column: $table.tempC,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get humidityPct => $composableBuilder(
    column: $table.humidityPct,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get pressureHpa => $composableBuilder(
    column: $table.pressureHpa,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get precipitationMm => $composableBuilder(
    column: $table.precipitationMm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get pressureDelta24h => $composableBuilder(
    column: $table.pressureDelta24h,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get pressureDelta48h => $composableBuilder(
    column: $table.pressureDelta48h,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get aqi => $composableBuilder(
    column: $table.aqi,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get enrichedAt => $composableBuilder(
    column: $table.enrichedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get enrichError => $composableBuilder(
    column: $table.enrichError,
    builder: (column) => ColumnOrderings(column),
  );

  $$MigraineEventsTableOrderingComposer get eventId {
    final $$MigraineEventsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.eventId,
      referencedTable: $db.migraineEvents,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MigraineEventsTableOrderingComposer(
            $db: $db,
            $table: $db.migraineEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DerivedFactorsTableAnnotationComposer
    extends Composer<_$MegrimDatabase, $DerivedFactorsTable> {
  $$DerivedFactorsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get dayOfWeek =>
      $composableBuilder(column: $table.dayOfWeek, builder: (column) => column);

  GeneratedColumn<String> get season =>
      $composableBuilder(column: $table.season, builder: (column) => column);

  GeneratedColumn<String> get timeOfDayBucket => $composableBuilder(
    column: $table.timeOfDayBucket,
    builder: (column) => column,
  );

  GeneratedColumn<double> get daylightHours => $composableBuilder(
    column: $table.daylightHours,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get sunriseUtc => $composableBuilder(
    column: $table.sunriseUtc,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get sunsetUtc =>
      $composableBuilder(column: $table.sunsetUtc, builder: (column) => column);

  GeneratedColumn<String> get moonPhase =>
      $composableBuilder(column: $table.moonPhase, builder: (column) => column);

  GeneratedColumn<double> get moonIllumination => $composableBuilder(
    column: $table.moonIllumination,
    builder: (column) => column,
  );

  GeneratedColumn<double> get tempC =>
      $composableBuilder(column: $table.tempC, builder: (column) => column);

  GeneratedColumn<double> get humidityPct => $composableBuilder(
    column: $table.humidityPct,
    builder: (column) => column,
  );

  GeneratedColumn<double> get pressureHpa => $composableBuilder(
    column: $table.pressureHpa,
    builder: (column) => column,
  );

  GeneratedColumn<double> get precipitationMm => $composableBuilder(
    column: $table.precipitationMm,
    builder: (column) => column,
  );

  GeneratedColumn<double> get pressureDelta24h => $composableBuilder(
    column: $table.pressureDelta24h,
    builder: (column) => column,
  );

  GeneratedColumn<double> get pressureDelta48h => $composableBuilder(
    column: $table.pressureDelta48h,
    builder: (column) => column,
  );

  GeneratedColumn<int> get aqi =>
      $composableBuilder(column: $table.aqi, builder: (column) => column);

  GeneratedColumn<DateTime> get enrichedAt => $composableBuilder(
    column: $table.enrichedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get enrichError => $composableBuilder(
    column: $table.enrichError,
    builder: (column) => column,
  );

  $$MigraineEventsTableAnnotationComposer get eventId {
    final $$MigraineEventsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.eventId,
      referencedTable: $db.migraineEvents,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MigraineEventsTableAnnotationComposer(
            $db: $db,
            $table: $db.migraineEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DerivedFactorsTableTableManager
    extends
        RootTableManager<
          _$MegrimDatabase,
          $DerivedFactorsTable,
          DerivedFactor,
          $$DerivedFactorsTableFilterComposer,
          $$DerivedFactorsTableOrderingComposer,
          $$DerivedFactorsTableAnnotationComposer,
          $$DerivedFactorsTableCreateCompanionBuilder,
          $$DerivedFactorsTableUpdateCompanionBuilder,
          (DerivedFactor, $$DerivedFactorsTableReferences),
          DerivedFactor,
          PrefetchHooks Function({bool eventId})
        > {
  $$DerivedFactorsTableTableManager(
    _$MegrimDatabase db,
    $DerivedFactorsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DerivedFactorsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DerivedFactorsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DerivedFactorsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> eventId = const Value.absent(),
                Value<int?> dayOfWeek = const Value.absent(),
                Value<String?> season = const Value.absent(),
                Value<String?> timeOfDayBucket = const Value.absent(),
                Value<double?> daylightHours = const Value.absent(),
                Value<DateTime?> sunriseUtc = const Value.absent(),
                Value<DateTime?> sunsetUtc = const Value.absent(),
                Value<String?> moonPhase = const Value.absent(),
                Value<double?> moonIllumination = const Value.absent(),
                Value<double?> tempC = const Value.absent(),
                Value<double?> humidityPct = const Value.absent(),
                Value<double?> pressureHpa = const Value.absent(),
                Value<double?> precipitationMm = const Value.absent(),
                Value<double?> pressureDelta24h = const Value.absent(),
                Value<double?> pressureDelta48h = const Value.absent(),
                Value<int?> aqi = const Value.absent(),
                Value<DateTime?> enrichedAt = const Value.absent(),
                Value<String?> enrichError = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DerivedFactorsCompanion(
                eventId: eventId,
                dayOfWeek: dayOfWeek,
                season: season,
                timeOfDayBucket: timeOfDayBucket,
                daylightHours: daylightHours,
                sunriseUtc: sunriseUtc,
                sunsetUtc: sunsetUtc,
                moonPhase: moonPhase,
                moonIllumination: moonIllumination,
                tempC: tempC,
                humidityPct: humidityPct,
                pressureHpa: pressureHpa,
                precipitationMm: precipitationMm,
                pressureDelta24h: pressureDelta24h,
                pressureDelta48h: pressureDelta48h,
                aqi: aqi,
                enrichedAt: enrichedAt,
                enrichError: enrichError,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String eventId,
                Value<int?> dayOfWeek = const Value.absent(),
                Value<String?> season = const Value.absent(),
                Value<String?> timeOfDayBucket = const Value.absent(),
                Value<double?> daylightHours = const Value.absent(),
                Value<DateTime?> sunriseUtc = const Value.absent(),
                Value<DateTime?> sunsetUtc = const Value.absent(),
                Value<String?> moonPhase = const Value.absent(),
                Value<double?> moonIllumination = const Value.absent(),
                Value<double?> tempC = const Value.absent(),
                Value<double?> humidityPct = const Value.absent(),
                Value<double?> pressureHpa = const Value.absent(),
                Value<double?> precipitationMm = const Value.absent(),
                Value<double?> pressureDelta24h = const Value.absent(),
                Value<double?> pressureDelta48h = const Value.absent(),
                Value<int?> aqi = const Value.absent(),
                Value<DateTime?> enrichedAt = const Value.absent(),
                Value<String?> enrichError = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DerivedFactorsCompanion.insert(
                eventId: eventId,
                dayOfWeek: dayOfWeek,
                season: season,
                timeOfDayBucket: timeOfDayBucket,
                daylightHours: daylightHours,
                sunriseUtc: sunriseUtc,
                sunsetUtc: sunsetUtc,
                moonPhase: moonPhase,
                moonIllumination: moonIllumination,
                tempC: tempC,
                humidityPct: humidityPct,
                pressureHpa: pressureHpa,
                precipitationMm: precipitationMm,
                pressureDelta24h: pressureDelta24h,
                pressureDelta48h: pressureDelta48h,
                aqi: aqi,
                enrichedAt: enrichedAt,
                enrichError: enrichError,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$DerivedFactorsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({eventId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (eventId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.eventId,
                                referencedTable: $$DerivedFactorsTableReferences
                                    ._eventIdTable(db),
                                referencedColumn:
                                    $$DerivedFactorsTableReferences
                                        ._eventIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$DerivedFactorsTableProcessedTableManager =
    ProcessedTableManager<
      _$MegrimDatabase,
      $DerivedFactorsTable,
      DerivedFactor,
      $$DerivedFactorsTableFilterComposer,
      $$DerivedFactorsTableOrderingComposer,
      $$DerivedFactorsTableAnnotationComposer,
      $$DerivedFactorsTableCreateCompanionBuilder,
      $$DerivedFactorsTableUpdateCompanionBuilder,
      (DerivedFactor, $$DerivedFactorsTableReferences),
      DerivedFactor,
      PrefetchHooks Function({bool eventId})
    >;
typedef $$AppSettingsTableCreateCompanionBuilder =
    AppSettingsCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$AppSettingsTableUpdateCompanionBuilder =
    AppSettingsCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$AppSettingsTableFilterComposer
    extends Composer<_$MegrimDatabase, $AppSettingsTable> {
  $$AppSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppSettingsTableOrderingComposer
    extends Composer<_$MegrimDatabase, $AppSettingsTable> {
  $$AppSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppSettingsTableAnnotationComposer
    extends Composer<_$MegrimDatabase, $AppSettingsTable> {
  $$AppSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$AppSettingsTableTableManager
    extends
        RootTableManager<
          _$MegrimDatabase,
          $AppSettingsTable,
          AppSetting,
          $$AppSettingsTableFilterComposer,
          $$AppSettingsTableOrderingComposer,
          $$AppSettingsTableAnnotationComposer,
          $$AppSettingsTableCreateCompanionBuilder,
          $$AppSettingsTableUpdateCompanionBuilder,
          (
            AppSetting,
            BaseReferences<_$MegrimDatabase, $AppSettingsTable, AppSetting>,
          ),
          AppSetting,
          PrefetchHooks Function()
        > {
  $$AppSettingsTableTableManager(_$MegrimDatabase db, $AppSettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AppSettingsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => AppSettingsCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$MegrimDatabase,
      $AppSettingsTable,
      AppSetting,
      $$AppSettingsTableFilterComposer,
      $$AppSettingsTableOrderingComposer,
      $$AppSettingsTableAnnotationComposer,
      $$AppSettingsTableCreateCompanionBuilder,
      $$AppSettingsTableUpdateCompanionBuilder,
      (
        AppSetting,
        BaseReferences<_$MegrimDatabase, $AppSettingsTable, AppSetting>,
      ),
      AppSetting,
      PrefetchHooks Function()
    >;
typedef $$VocabulariesTableCreateCompanionBuilder =
    VocabulariesCompanion Function({
      required String kind,
      required String value,
      Value<int> sort,
      Value<int> rowid,
    });
typedef $$VocabulariesTableUpdateCompanionBuilder =
    VocabulariesCompanion Function({
      Value<String> kind,
      Value<String> value,
      Value<int> sort,
      Value<int> rowid,
    });

class $$VocabulariesTableFilterComposer
    extends Composer<_$MegrimDatabase, $VocabulariesTable> {
  $$VocabulariesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sort => $composableBuilder(
    column: $table.sort,
    builder: (column) => ColumnFilters(column),
  );
}

class $$VocabulariesTableOrderingComposer
    extends Composer<_$MegrimDatabase, $VocabulariesTable> {
  $$VocabulariesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sort => $composableBuilder(
    column: $table.sort,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$VocabulariesTableAnnotationComposer
    extends Composer<_$MegrimDatabase, $VocabulariesTable> {
  $$VocabulariesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<int> get sort =>
      $composableBuilder(column: $table.sort, builder: (column) => column);
}

class $$VocabulariesTableTableManager
    extends
        RootTableManager<
          _$MegrimDatabase,
          $VocabulariesTable,
          Vocabulary,
          $$VocabulariesTableFilterComposer,
          $$VocabulariesTableOrderingComposer,
          $$VocabulariesTableAnnotationComposer,
          $$VocabulariesTableCreateCompanionBuilder,
          $$VocabulariesTableUpdateCompanionBuilder,
          (
            Vocabulary,
            BaseReferences<_$MegrimDatabase, $VocabulariesTable, Vocabulary>,
          ),
          Vocabulary,
          PrefetchHooks Function()
        > {
  $$VocabulariesTableTableManager(_$MegrimDatabase db, $VocabulariesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$VocabulariesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$VocabulariesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$VocabulariesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> kind = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> sort = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => VocabulariesCompanion(
                kind: kind,
                value: value,
                sort: sort,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String kind,
                required String value,
                Value<int> sort = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => VocabulariesCompanion.insert(
                kind: kind,
                value: value,
                sort: sort,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$VocabulariesTableProcessedTableManager =
    ProcessedTableManager<
      _$MegrimDatabase,
      $VocabulariesTable,
      Vocabulary,
      $$VocabulariesTableFilterComposer,
      $$VocabulariesTableOrderingComposer,
      $$VocabulariesTableAnnotationComposer,
      $$VocabulariesTableCreateCompanionBuilder,
      $$VocabulariesTableUpdateCompanionBuilder,
      (
        Vocabulary,
        BaseReferences<_$MegrimDatabase, $VocabulariesTable, Vocabulary>,
      ),
      Vocabulary,
      PrefetchHooks Function()
    >;

class $MegrimDatabaseManager {
  final _$MegrimDatabase _db;
  $MegrimDatabaseManager(this._db);
  $$MigraineEventsTableTableManager get migraineEvents =>
      $$MigraineEventsTableTableManager(_db, _db.migraineEvents);
  $$DerivedFactorsTableTableManager get derivedFactors =>
      $$DerivedFactorsTableTableManager(_db, _db.derivedFactors);
  $$AppSettingsTableTableManager get appSettings =>
      $$AppSettingsTableTableManager(_db, _db.appSettings);
  $$VocabulariesTableTableManager get vocabularies =>
      $$VocabulariesTableTableManager(_db, _db.vocabularies);
}
