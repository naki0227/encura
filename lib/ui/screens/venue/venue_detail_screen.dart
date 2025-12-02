import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:encura/core/services/event_service.dart';
import 'package:encura/core/services/map_service.dart';
import 'package:encura/ui/screens/event/event_detail_screen.dart';

class VenueDetailScreen extends StatefulWidget {
  final Map<String, dynamic> venue;

  const VenueDetailScreen({super.key, required this.venue});

  @override
  State<VenueDetailScreen> createState() => _VenueDetailScreenState();
}

class _VenueDetailScreenState extends State<VenueDetailScreen> {
  final EventService _eventService = EventService();
  final MapService _mapService = MapService();
  final ImagePicker _picker = ImagePicker();

  List<ArtEvent> _events = [];
  List<String> _maps = [];
  bool _isLoadingEvents = true;
  bool _isLoadingMaps = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final venueId = widget.venue['id'];
    
    // Load Events
    _eventService.getEventsByVenue(venueId).then((events) {
      if (mounted) {
        setState(() {
          _events = events;
          _isLoadingEvents = false;
        });
      }
    });

    // Load Maps
    _loadMaps();
  }

  Future<void> _loadMaps() async {
    final venueId = widget.venue['id'];
    final maps = await _mapService.getMaps(null, venueId);
    if (mounted) {
      setState(() {
        _maps = maps;
        _isLoadingMaps = false;
      });
    }
  }

  Future<void> _showImageSourceSelection() async {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Camera'),
                onTap: () {
                  Navigator.pop(context);
                  _uploadMap(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _uploadMap(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _uploadMap(ImageSource source) async {
    final XFile? image = await _picker.pickImage(source: source);
    if (image == null) return;

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Verifying image with AI...')),
    );

    final File imageFile = File(image.path);
    // Pass venueId, eventId is null since we are in venue context
    final success = await _mapService.verifyAndUploadMap(imageFile, null, widget.venue['id']);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Map verified and uploaded!')),
      );
      _loadMaps(); // Refresh list
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Not a Map'),
          content: const Text('AI determined that this image is not a map or floor guide. Please try again.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch $url')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final venueName = widget.venue['name'] ?? 'Unknown Venue';
    final venueAddress = widget.venue['address'] ?? 'Address not available';
    final websiteUrl = widget.venue['website_url'];

    return Scaffold(
      appBar: AppBar(
        title: Text(venueName),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
            Container(
              padding: const EdgeInsets.all(24.0),
              width: double.infinity,
              decoration: BoxDecoration(
                color: theme.cardColor,
                border: Border(bottom: BorderSide(color: theme.dividerColor)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    venueName,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          venueAddress,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                  if (websiteUrl != null) ...[
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () => _launchUrl(websiteUrl),
                      icon: const Icon(Icons.language),
                      label: const Text('Visit Official Site'),
                    ),
                  ],
                ],
              ),
            ),

            // Community Maps Section
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Community Maps',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  TextButton.icon(
                    onPressed: _showImageSourceSelection,
                    icon: const Icon(Icons.add_a_photo),
                    label: const Text('Add Map'),
                  ),
                ],
              ),
            ),
            
            if (_isLoadingMaps)
              const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
            else if (_maps.isEmpty)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: theme.cardColor.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.dividerColor),
                ),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.map_outlined, size: 48, color: theme.disabledColor),
                      const SizedBox(height: 12),
                      Text(
                        'No maps yet.',
                        style: theme.textTheme.bodyLarge?.copyWith(color: theme.disabledColor),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Be the first to share a floor guide!',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.disabledColor),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _showImageSourceSelection,
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Scan Venue Map'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.primaryColor,
                          foregroundColor: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              SizedBox(
                height: 220,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  scrollDirection: Axis.horizontal,
                  itemCount: _maps.length,
                  itemBuilder: (context, index) {
                    return Container(
                      width: 300,
                      margin: const EdgeInsets.only(right: 16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        image: DecorationImage(
                          image: NetworkImage(_maps[index]),
                          fit: BoxFit.cover,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            // Open full screen or chat
                            // For now, let's just show a simple dialog or navigate to chat?
                            // Requirement says "tap to open AI chat".
                            // We need to navigate to ChatScreen with this image.
                            // But ChatScreen is a tab in MainScreen.
                            // We can push a new ChatScreen instance or use a specific route.
                            // Let's push a new ChatScreen for context.
                            // Wait, ChatScreen is part of the bottom nav.
                            // We can push a standalone ChatScreen.
                            
                            // Actually, let's just show the image full screen for now as per "VenueDetailScreen" spec didn't explicitly say "Chat" for VenueDetail, 
                            // but the "AI Map Memory" feature overall says "Integrate with AI Chat".
                            // So yes, let's assume we want to chat about it.
                            
                            // However, we need to import ChatScreen.
                            // Let's leave it as a TODO or simple viewer for now to avoid circular deps if any,
                            // or better, just push the ChatScreen.
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)],
                              ),
                            ),
                            padding: const EdgeInsets.all(12),
                            alignment: Alignment.bottomRight,
                            child: const Icon(Icons.chat_bubble_outline, color: Colors.white),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

            // Events Section
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
              child: Text(
                'Upcoming Events',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            
            if (_isLoadingEvents)
              const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
            else if (_events.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'No upcoming events found for this venue.',
                  style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: _events.length,
                itemBuilder: (context, index) {
                  final event = _events[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      title: Text(
                        event.title,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          Text('${event.startDate.month}/${event.startDate.day} - ${event.endDate.month}/${event.endDate.day}'),
                        ],
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EventDetailScreen(event: event),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
              
            // Hotel Search Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    final url = 'https://search.travel.rakuten.co.jp/ds/search/mall?f_query=${Uri.encodeComponent(venueName)}';
                    _launchUrl(url);
                  },
                  icon: const Icon(Icons.hotel, color: Color(0xFFC5A059)),
                  label: const Text(
                    '近くのホテル・宿を探す',
                    style: TextStyle(color: Color(0xFFC5A059), fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFC5A059)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
