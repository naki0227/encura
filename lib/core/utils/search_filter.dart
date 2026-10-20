/// PostgREST `or=(...)` filter that matches [query] in any of [columns].
///
/// The value is double-quoted so that commas, dots and parentheses in what
/// the user typed are treated as text instead of breaking the filter (which
/// made such searches silently return nothing).
String ilikeAnyFilter(List<String> columns, String query) {
  final escaped = query.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
  return columns.map((c) => '$c.ilike."%$escaped%"').join(',');
}
