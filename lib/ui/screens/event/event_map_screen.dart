import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'event_view_model.dart';

class EventMapScreen extends StatelessWidget {
  const EventMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => EventViewModel()..loadEvents(),
      child: const _EventMapScreenContent(),
    );
  }
}

class _EventMapScreenContent extends StatelessWidget {
  const _EventMapScreenContent();

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<EventViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Event Hunter'),
      ),
      body: viewModel.isLoading
          ? const Center(child: CircularProgressIndicator())
          : FlutterMap(
              options: MapOptions(
                initialCenter: viewModel.currentLocation ?? const LatLng(35.6895, 139.6917), // Tokyo default
                initialZoom: 13.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.enludus.encura',
                ),
                MarkerLayer(
                  markers: [
                    if (viewModel.currentLocation != null)
                      Marker(
                        point: viewModel.currentLocation!,
                        width: 40,
                        height: 40,
                        child: const Icon(Icons.my_location, color: Colors.blue),
                      ),
                    ...viewModel.events.map((event) => Marker(
                          point: event.location,
                          width: 40,
                          height: 40,
                          child: GestureDetector(
                            onTap: () {
                              showModalBottomSheet(
                                context: context,
                                builder: (context) => Container(
                                  padding: const EdgeInsets.all(16.0),
                                  width: double.infinity,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(event.title, style: Theme.of(context).textTheme.titleLarge),
                                      const SizedBox(height: 8),
                                      Text(event.venue, style: Theme.of(context).textTheme.titleMedium),
                                      const SizedBox(height: 8),
                                      Text(event.summary ?? 'No description'),
                                    ],
                                  ),
                                ),
                              );
                            },
                            child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                          ),
                        )),
                  ],
                ),
              ],
            ),
    );
  }
}
