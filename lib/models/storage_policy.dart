class StoragePolicy {
  const StoragePolicy({
    this.autoCleanup = true,
    this.retentionDays = 30,
    this.maxStorageMb = 1024,
  });

  final bool autoCleanup;
  final int retentionDays;
  final int maxStorageMb;

  StoragePolicy copyWith({
    bool? autoCleanup,
    int? retentionDays,
    int? maxStorageMb,
  }) =>
      StoragePolicy(
        autoCleanup: autoCleanup ?? this.autoCleanup,
        retentionDays: retentionDays ?? this.retentionDays,
        maxStorageMb: maxStorageMb ?? this.maxStorageMb,
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'autoCleanup': autoCleanup,
        'retentionDays': retentionDays,
        'maxStorageMb': maxStorageMb,
      };

  factory StoragePolicy.fromJson(Map<String, dynamic> json) => StoragePolicy(
        autoCleanup: json['autoCleanup'] as bool? ?? true,
        retentionDays: ((json['retentionDays'] as num?)?.toInt() ?? 30).clamp(1, 3650).toInt(),
        maxStorageMb: ((json['maxStorageMb'] as num?)?.toInt() ?? 1024).clamp(128, 32768).toInt(),
      );
}
