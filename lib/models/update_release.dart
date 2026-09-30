class AppBuildVersion implements Comparable<AppBuildVersion> {
  const AppBuildVersion({required this.version, required this.build});

  final String version;
  final int build;

  String get display => version;
  String get storageValue => '$version+$build';

  static AppBuildVersion? tryParse(String? raw) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) return null;
    final parts = value.split('+');
    if (parts.length != 2) return null;
    final build = int.tryParse(parts[1]);
    final versionParts = parts[0].split('.');
    if (build == null || versionParts.length != 3) return null;
    if (versionParts.any((part) => int.tryParse(part) == null)) return null;
    return AppBuildVersion(version: parts[0], build: build);
  }

  List<int> get _semanticParts => version
      .split('.')
      .map((part) => int.tryParse(part) ?? 0)
      .toList(growable: false);

  @override
  int compareTo(AppBuildVersion other) {
    final current = _semanticParts;
    final candidate = other._semanticParts;
    final length = current.length > candidate.length
        ? current.length
        : candidate.length;
    for (var index = 0; index < length; index++) {
      final left = index < current.length ? current[index] : 0;
      final right = index < candidate.length ? candidate[index] : 0;
      final comparison = left.compareTo(right);
      if (comparison != 0) return comparison;
    }
    return build.compareTo(other.build);
  }

  @override
  bool operator ==(Object other) =>
      other is AppBuildVersion && other.version == version && other.build == build;

  @override
  int get hashCode => Object.hash(version, build);
}

class UpdateRelease {
  const UpdateRelease({
    required this.version,
    required this.changes,
  });

  final AppBuildVersion version;
  final List<String> changes;
}

class UpdateNewsDecision {
  const UpdateNewsDecision({
    required this.installedVersion,
    required this.releases,
  });

  final AppBuildVersion installedVersion;
  final List<UpdateRelease> releases;

  bool get shouldShow => releases.isNotEmpty;

  List<String> get changes {
    final seen = <String>{};
    final merged = <String>[];
    for (final release in releases.reversed) {
      for (final change in release.changes) {
        if (seen.add(change)) merged.add(change);
      }
    }
    return merged;
  }
}
