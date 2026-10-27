import 'package:supabase_flutter/supabase_flutter.dart';

import 'event_service.dart';

/// Exhibitions for the Learn tab, loaded once per launch: those on now,
/// those coming, and those that ended in the last two years (so a page can
/// say where a work or an artist was shown).
class ExhibitionsStore {
  ExhibitionsStore._();

  static final instance = ExhibitionsStore._();

  Future<List<ArtEvent>>? _events;

  Future<List<ArtEvent>> load() => _events ??= _fetch();

  Future<List<ArtEvent>> _fetch() async {
    try {
      final since = DateTime.now().subtract(const Duration(days: 730));
      final from = '${since.year}-${since.month.toString().padLeft(2, '0')}-${since.day.toString().padLeft(2, '0')}';
      final rows = await Supabase.instance.client
          .from('events')
          .select('id, title, venue, venue_id, location, description_json, source_url, start_date, end_date')
          .gte('end_date', from)
          .order('start_date', ascending: true);
      return (rows as List).map((e) => ArtEvent.fromJson(e)).toList();
    } catch (e) {
      // Try again next time a page asks.
      _events = null;
      return const [];
    }
  }
}
