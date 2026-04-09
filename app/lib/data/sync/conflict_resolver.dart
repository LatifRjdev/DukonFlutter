/// Simple last-write-wins conflict resolution strategy.
///
/// When a conflict is detected between local and remote versions of an entity,
/// the version with the most recent timestamp wins. This is a pragmatic
/// approach suitable for single-user retail store management where conflicts
/// are rare.
class ConflictResolver {
  const ConflictResolver();

  /// Resolve a conflict between a local and remote entity.
  ///
  /// Returns the winning version's data. The [localData] and [remoteData] maps
  /// must contain an `updatedAt` or `createdAt` timestamp field.
  ///
  /// If timestamps are equal or missing, the remote version wins (server is
  /// the source of truth).
  Map<String, dynamic> resolve({
    required Map<String, dynamic> localData,
    required Map<String, dynamic> remoteData,
  }) {
    final localTimestamp = _extractTimestamp(localData);
    final remoteTimestamp = _extractTimestamp(remoteData);

    if (localTimestamp != null &&
        remoteTimestamp != null &&
        localTimestamp.isAfter(remoteTimestamp)) {
      return localData;
    }

    // Remote wins by default (server as source of truth)
    return remoteData;
  }

  /// Determine if the local version should overwrite the remote.
  bool shouldLocalWin({
    required Map<String, dynamic> localData,
    required Map<String, dynamic> remoteData,
  }) {
    final localTimestamp = _extractTimestamp(localData);
    final remoteTimestamp = _extractTimestamp(remoteData);

    if (localTimestamp != null &&
        remoteTimestamp != null &&
        localTimestamp.isAfter(remoteTimestamp)) {
      return true;
    }
    return false;
  }

  DateTime? _extractTimestamp(Map<String, dynamic> data) {
    final updatedAt = data['updatedAt'] ?? data['updated_at'];
    final createdAt = data['createdAt'] ?? data['created_at'];

    final raw = updatedAt ?? createdAt;
    if (raw == null) return null;

    if (raw is DateTime) return raw;
    if (raw is String) {
      return DateTime.tryParse(raw);
    }
    return null;
  }
}
