Map<String, dynamic> safeMapCast(dynamic input) {
  if (input == null) return {};

  if (input is Map) {
    return Map<String, dynamic>.fromEntries(
      input.entries.map((entry) {
        dynamic value = entry.value;
        if (value is Map) {
          value = safeMapCast(value); // Recursively convert nested maps
        } else if (value is List) {
          value = value
              .map((item) => item is Map ? safeMapCast(item) : item)
              .toList();
        }
        return MapEntry(entry.key.toString(), value);
      }),
    );
  }
  return {};
}

// Helper to ensure a value is a String or returns empty string
String safeString(dynamic value) => value?.toString() ?? '';

// Helper to ensure a value is a double or returns 0.0
double safeDouble(dynamic value) {
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}
