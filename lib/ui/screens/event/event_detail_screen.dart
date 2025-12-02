import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/services/event_service.dart';
import '../../../core/services/map_service.dart';
import '../chat/chat_screen.dart'; // Assuming we can navigate to chat or pass context

class EventDetailScreen extends StatefulWidget {
  final ArtEvent event;

  const EventDetailScreen({super.key, required this.event});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  final MapService _mapService = MapService();
  final ImagePicker _picker = ImagePicker();
  List<String> _maps = [];
  bool _isLoadingMaps = true;

  @override
  void initState() {
    super.initState();
    _loadMaps();
  }

  Future<void> _loadMaps() async {
    // If event has venue_id, use that. Otherwise fallback to event_id for backward compatibility or if venue logic not fully migrated
    // The ArtEvent model needs to be updated to include venue_id first.
    // Assuming we update ArtEvent model next.
    
    // For now, let's assume we fetch maps by event_id as before, 
    // BUT the requirement says "venue_maps table is linked to venue_id".
    // So we need to:
    // 1. Get venue_id from event (if available)
    // 2. Fetch maps by venue_id
    
    // Since we haven't updated ArtEvent model in Dart yet, let's do that first.
    // I will pause this edit and update ArtEvent model first.
    
    // Wait, I can just fetch by  Future<void> _loadMaps() async {
    final maps = await _mapService.getMaps(widget.event.id, widget.event.venueId);
    if (mounted) {
      setState(() {
        _maps = maps;
        _isLoadingMaps = false;
      });
    }
  }

  Future<void> _scanAndUploadMap() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.camera);
    if (image == null) return;

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Verifying image with AI...')),
    );

    final File imageFile = File(image.path);
    final success = await _mapService.verifyAndUploadMap(imageFile, widget.event.id, widget.event.venueId);

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

  void _openChatWithMap(String imageUrl) {
    // Navigate to ChatScreen with initial image context
    // Note: This requires ChatScreen to accept an initial image URL or context.
    // For now, we'll just show a placeholder message or navigate.
    // Ideally, pass arguments to ChatScreen.
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(initialImageUrl: imageUrl),
      ),
    );
  }

  Future<void> _launchMap() async {
    // Try to launch with coordinates first
    final Uri googleMapsUrl = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${widget.event.location.latitude},${widget.event.location.longitude}');
    
    if (await canLaunchUrl(googleMapsUrl)) {
      await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
    } else {
      // Fallback to venue name search
      final Uri venueSearchUrl = Uri.parse(
          'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(widget.event.venue)}');
      if (await canLaunchUrl(venueSearchUrl)) {
        await launchUrl(venueSearchUrl, mode: LaunchMode.externalApplication);
      } else {
        // debugPrint('Could not launch map.');
      }
    }
  }

  Future<void> _launchOfficialSite() async {
    if (widget.event.sourceUrl != null) {
      final Uri url = Uri.parse(widget.event.sourceUrl!);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy/MM/dd');

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                widget.event.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Placeholder for event image if available, or a default pattern
                  Container(
                    color: Theme.of(context).primaryColor.withValues(alpha: 0.2),
                    child: const Center(
                      child: Icon(Icons.event, size: 64, color: Colors.white24),
                    ),
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black54],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date Range
                  Row(
                    children: [
                      Icon(Icons.calendar_today, color: Theme.of(context).primaryColor, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        "${dateFormat.format(widget.event.startDate)} - ${dateFormat.format(widget.event.endDate)}",
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Venue Info
                  Text(
                    "Venue",
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Colors.grey,
                          letterSpacing: 1.2,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardTheme.color,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.event.venue,
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              // Address could go here if available
                            ],
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _launchMap,
                          icon: const Icon(Icons.map, size: 18),
                          label: const Text("Map"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor,
                            foregroundColor: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Description
                  if (widget.event.summary != null) ...[
                    Text(
                      "Highlights",
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: Colors.grey,
                            letterSpacing: 1.2,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.event.summary!,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            height: 1.6,
                          ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Official Link
                  if (widget.event.sourceUrl != null)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _launchOfficialSite,
                        icon: const Icon(Icons.language),
                        label: const Text("Visit Official Site"),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(color: Theme.of(context).primaryColor),
                        ),
                      ),
                    ),
                  
                  const SizedBox(height: 40),

                  // Community Maps Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Community Maps",
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      IconButton(
                        onPressed: _scanAndUploadMap,
                        icon: const Icon(Icons.add_a_photo),
                        tooltip: "Add Map",
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_maps.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.map_outlined, size: 48, color: Colors.grey[600]),
                          const SizedBox(height: 8),
                          Text(
                            "No maps yet.\nBe the first to share!",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey[400]),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _scanAndUploadMap,
                            icon: const Icon(Icons.camera_alt),
                            label: const Text("Scan Venue Map"),
                          ),
                        ],
                      ),
                    )
                  else
                    SizedBox(
                      height: 200,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _maps.length,
                        itemBuilder: (context, index) {
                          final imageUrl = _maps[index];
                          return GestureDetector(
                            onTap: () => _openChatWithMap(imageUrl),
                            child: Container(
                              width: 160,
                              margin: const EdgeInsets.only(right: 12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Theme.of(context).primaryColor.withValues(alpha: 0.3)),
                                image: DecorationImage(
                                  image: NetworkImage(imageUrl),
                                  fit: BoxFit.cover,
                                ),
                              ),
                              child: Stack(
                                children: [
                                  Positioned(
                                    bottom: 8,
                                    right: 8,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: Colors.black54,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.chat_bubble, color: Colors.white, size: 16),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
