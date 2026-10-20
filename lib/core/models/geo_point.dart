import 'dart:typed_data';

import 'package:latlong2/latlong.dart';

/// Reads a PostGIS point as Supabase returns it.
///
/// Depending on the column type and how the row was written, PostgREST hands
/// back GeoJSON, WKT (`POINT(lon lat)`, optionally with `SRID=4326;`) or hex
/// EWKB (`0101000020E6100000...`). Returns null when there is no usable point,
/// so callers can fall back instead of showing a made-up location.
LatLng? parseGeoPoint(Object? value) {
  if (value == null) return null;
  if (value is Map) return _fromGeoJson(value);
  if (value is String) {
    final text = value.trim();
    if (text.isEmpty) return null;
    return _fromWkt(text) ?? _fromHexEwkb(text);
  }
  return null;
}

LatLng? _point(double lon, double lat) {
  if (lat.isNaN || lon.isNaN || lat.abs() > 90 || lon.abs() > 180) return null;
  return LatLng(lat, lon);
}

LatLng? _fromGeoJson(Map value) {
  final coords = value['coordinates'];
  if (value['type'] != 'Point' || coords is! List || coords.length < 2) return null;
  final lon = coords[0], lat = coords[1];
  if (lon is! num || lat is! num) return null;
  return _point(lon.toDouble(), lat.toDouble());
}

final _wkt = RegExp(r'^(?:SRID=\d+;)?\s*POINT\s*\(\s*(\S+)\s+(\S+)\s*\)$', caseSensitive: false);

LatLng? _fromWkt(String text) {
  final match = _wkt.firstMatch(text);
  if (match == null) return null;
  final lon = double.tryParse(match.group(1)!);
  final lat = double.tryParse(match.group(2)!);
  if (lon == null || lat == null) return null;
  return _point(lon, lat);
}

final _hex = RegExp(r'^[0-9a-fA-F]+$');

LatLng? _fromHexEwkb(String text) {
  // byte order (1) + type (4) + x (8) + y (8), plus an optional SRID (4).
  if (!_hex.hasMatch(text) || text.length.isOdd || text.length < 42) return null;
  final bytes = Uint8List(text.length ~/ 2);
  for (var i = 0; i < bytes.length; i++) {
    bytes[i] = int.parse(text.substring(i * 2, i * 2 + 2), radix: 16);
  }
  final data = ByteData.sublistView(bytes);
  final endian = bytes[0] == 1 ? Endian.little : Endian.big;
  final type = data.getUint32(1, endian);
  if (type & 0xFF != 1) return null; // not a Point
  var offset = 5;
  if (type & 0x20000000 != 0) offset += 4; // SRID present
  if (bytes.length < offset + 16) return null;
  return _point(data.getFloat64(offset, endian), data.getFloat64(offset + 8, endian));
}
