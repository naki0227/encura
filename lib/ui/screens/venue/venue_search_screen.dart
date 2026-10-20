import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:encura/ui/screens/venue/venue_detail_screen.dart';
import 'package:encura/core/utils/venue_sort.dart';

class VenueSearchScreen extends StatefulWidget {
  const VenueSearchScreen({super.key});

  @override
  State<VenueSearchScreen> createState() => _VenueSearchScreenState();
}

class _VenueSearchScreenState extends State<VenueSearchScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final TextEditingController _searchController = TextEditingController();
  
  List<Map<String, dynamic>> _venues = [];
  bool _isLoading = false;
  String _activeTab = 'search'; // 'search' or 'nearby'

  @override
  void initState() {
    super.initState();
    _loadVenues();
  }

  Future<void> _loadVenues({String? query}) async {
    setState(() => _isLoading = true);
    try {
      var dbQuery = _supabase.from('venues').select();
      
      if (query != null && query.isNotEmpty) {
        dbQuery = dbQuery.ilike('name', '%$query%');
      }

      final data = await dbQuery.order('name');
      
      if (mounted) {
        setState(() {
          _venues = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading venues: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadNearbyVenues() async {
    setState(() {
      _isLoading = true;
      _activeTab = 'nearby';
    });

    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('位置情報が許可されていないため、近くの美術館を探せません。')),
          );
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      final data = await _supabase.from('venues').select();
      final sorted = sortByDistance(
        List<Map<String, dynamic>>.from(data),
        LatLng(position.latitude, position.longitude),
      );
      if (mounted) {
        setState(() {
          _venues = sorted;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading nearby venues: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Museums'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search museums...',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Theme.of(context).cardColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                    ),
                    onSubmitted: (value) {
                      setState(() => _activeTab = 'search');
                      _loadVenues(query: value);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _loadNearbyVenues,
                  icon: Icon(
                    Icons.near_me,
                    color: _activeTab == 'nearby' ? Theme.of(context).primaryColor : Colors.grey,
                  ),
                  tooltip: "Nearby",
                ),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _venues.isEmpty
              ? const Center(child: Text('No museums found'))
              : ListView.builder(
                  itemCount: _venues.length,
                  itemBuilder: (context, index) {
                    final venue = _venues[index];
                    return ListTile(
                      leading: const Icon(Icons.account_balance),
                      title: Text(venue['name'] ?? 'Unknown'),
                      subtitle: Text(venue['address'] ?? 'No address info'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => VenueDetailScreen(venue: venue),
                          ),
                        );
                      },
                    );
                  },
                ),
    );
  }
}

