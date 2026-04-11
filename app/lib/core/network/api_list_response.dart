/// Helpers for decoding list-shaped API responses that arrive in one of the
/// three historical shapes this codebase has to handle:
///
///   1. A bare JSON array: `[{...}, {...}]` (e.g. `/stores/:id/staff`)
///   2. A pagination envelope: `{"data": [...], "total": n, "totalPages": n}`
///      (e.g. `/stores/:id/customers`, `/stores/:id/suppliers`)
///   3. A double-wrapped envelope used by a few older endpoints:
///      `{"data": {"items": [...], "total": n, "totalPages": n}}`
///
/// Before this helper existed, each datasource hardcoded a single shape and
/// crashed with `List<dynamic> is not a subtype of Map<String, dynamic>` or
/// `String is not a subtype of ...` whenever the backend returned a different
/// shape than what the Flutter parser expected (FD-P0-002 / P0-004 / P0-005).
class ApiListResponse<T> {
  final List<T> items;
  final int total;
  final int totalPages;

  const ApiListResponse({
    required this.items,
    required this.total,
    required this.totalPages,
  });

  /// Decode a Dio response body into an [ApiListResponse]. [mapItem] is called
  /// once per raw JSON element to convert it into a [T]. Any shape the backend
  /// returns is accepted; unknown shapes yield an empty list rather than
  /// throwing so the UI shows an empty state instead of crashing.
  static ApiListResponse<T> decode<T>(
    dynamic data,
    T Function(Map<String, dynamic>) mapItem,
  ) {
    final rawList = _extractList(data);
    final totals = _extractTotals(data, rawList.length);
    return ApiListResponse<T>(
      items: rawList
          .whereType<Map<String, dynamic>>()
          .map(mapItem)
          .toList(growable: false),
      total: totals.total,
      totalPages: totals.totalPages,
    );
  }

  static List<dynamic> _extractList(dynamic data) {
    if (data is List) return data;
    if (data is Map<String, dynamic>) {
      final dataField = data['data'];
      if (dataField is List) return dataField;
      if (dataField is Map<String, dynamic>) {
        final items = dataField['items'];
        if (items is List) return items;
      }
      final items = data['items'];
      if (items is List) return items;
    }
    return const [];
  }

  static ({int total, int totalPages}) _extractTotals(
    dynamic data,
    int fallbackTotal,
  ) {
    if (data is Map<String, dynamic>) {
      final inner = data['data'];
      final envelope = inner is Map<String, dynamic> ? inner : data;
      final total = (envelope['total'] as num?)?.toInt() ?? fallbackTotal;
      final totalPages = (envelope['totalPages'] as num?)?.toInt() ?? 1;
      return (total: total, totalPages: totalPages);
    }
    return (total: fallbackTotal, totalPages: 1);
  }
}

/// Decode a single-object API response that may arrive as either a plain JSON
/// object or wrapped in `{"data": {...}}`. Returns null when the payload is not
/// a map at all (e.g. empty 200 body, bare string) — callers can decide how to
/// handle that instead of hitting a cast exception.
Map<String, dynamic>? decodeApiObject(dynamic data) {
  if (data is Map<String, dynamic>) {
    final inner = data['data'];
    if (inner is Map<String, dynamic>) return inner;
    return data;
  }
  return null;
}
