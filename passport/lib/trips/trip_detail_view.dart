// lib/trip_detail_view.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // for DateFormat
import 'package:http/http.dart' as http;
import 'dart:convert';

class TripDetailView extends StatefulWidget {
  final Map<String, dynamic> trip;
  final VoidCallback onBack;

  const TripDetailView({
    Key? key,
    required this.trip,
    required this.onBack,
  }) : super(key: key);

  @override
  _TripDetailViewState createState() => _TripDetailViewState();
}

class _TripDetailViewState extends State<TripDetailView> {
  // Supply your Mapbox token here or load it from configuration
  static const String _mapboxAccessToken = 'sk.eyJ1IjoiY29ubm9yY2FtcDEyIiwiYSI6ImNtNW42bjJ1cDA4MGUybm9tM3cxNWdwMnUifQ.74B36OWlxmAAfrqSkA_zRA';

  late Future<List<Map<String, dynamic>>> _stopsFuture;

  @override
  void initState() {
    super.initState();
    _stopsFuture = _fetchStopsWithPlaceNames();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.trip['title'] ?? 'Untitled Trip';
    final startIso = widget.trip['timeframe']?['start'] ?? '';
    final endIso = widget.trip['timeframe']?['end'] ?? '';
    final dateDisplay = (startIso.isNotEmpty && endIso.isNotEmpty)
        ? "${_formatFriendlyDate(startIso)} - ${_formatFriendlyDate(endIso)}"
        : "Unknown Date";

    final stops = widget.trip['stops'] as List<dynamic>? ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Title only
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          const Text(
            "Trip Dates:",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          Text(dateDisplay),
          const SizedBox(height: 24),
          const Text(
            "Stops:",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          // Display stops as a list
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: stops.length,
            itemBuilder: (context, index) {
              final stop = stops[index];
              final city = stop['city'] ?? 'Unknown';
              final startTime = stop['timeframe']?['start'] ?? '';
              final endTime = stop['timeframe']?['end'] ?? '';
              
              // Format dates
              final startDate = _formatFriendlyDate(startTime);
              final endDate = _formatFriendlyDate(endTime);
              final dateDisplay = startDate == endDate 
                  ? startDate 
                  : '$startDate - $endDate';
              
              final duration = _calculateDuration(startTime, endTime);

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text('${index + 1}'),
                  ),
                  title: Text(city),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(dateDisplay),
                      if (duration.isNotEmpty) Text(duration),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _fetchStopsWithPlaceNames() async {
    final locations = widget.trip['locations'] as List<dynamic>?;

    if (locations == null || locations.isEmpty) {
      return [];
    }

    List<Map<String, dynamic>> stopsWithNames = [];
    for (final loc in locations) {
      final lat = (loc['latitude'] as num).toDouble();
      final lon = (loc['longitude'] as num).toDouble();
      final timestamp = loc['timestamp'] as String? ?? '';

      final placeName = await _fetchPlaceName(lat, lon);
      stopsWithNames.add({
        'latitude': lat,
        'longitude': lon,
        'timestamp': timestamp,
        'placeName': placeName,
      });
    }
    return stopsWithNames;
  }

Future<String> _fetchPlaceName(double latitude, double longitude) async {
  final url = Uri.parse(
    'https://api.mapbox.com/geocoding/v5/mapbox.places/'
    '$longitude,$latitude.json?access_token=$_mapboxAccessToken&types=place&language=en'
  );
  try {
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final features = data['features'] as List<dynamic>;
      if (features.isNotEmpty) {
        // Return the 'text' field from the first feature which should now be a city
        return features[0]['text'] ?? 'Unknown';
      }
    }
    return 'Unknown';
  } catch (e) {
    return 'Unknown';
  }
}

  Widget _buildErrorContent(String errorMessage) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBack,
              ),
              const Expanded(
                child: Text(
                  'Error',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text("Failed to retrieve stops:\n$errorMessage"),
        ],
      ),
    );
  }

  Widget _buildNoStopsContent(String title, String dateDisplay) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          const Text(
            "Trip Dates:",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          Text(dateDisplay),
          const SizedBox(height: 24),
          const Text("No stops found for this trip."),
        ],
      ),
    );
  }

  Widget _buildDateHeader() {
    final timeframe = widget.trip['timeframe'];
    final startDate = DateTime.parse(timeframe['start']);
    final endDate = DateTime.parse(timeframe['end']);

    final String dateText;
    if (startDate.year == endDate.year && 
        startDate.month == endDate.month && 
        startDate.day == endDate.day) {
      dateText = DateFormat('MMMM d, yyyy').format(startDate);
    } else {
      dateText = '${DateFormat('MMM d').format(startDate)} - ${DateFormat('MMM d, yyyy').format(endDate)}';
    }

    return Text(
      dateText,
      style: TextStyle(
        fontSize: 16,
        color: Colors.grey[600],
      ),
    );
  }

  /// Convert ISO8601 to a friendly date string, e.g. "Jan. 15th, 2025"
  String _formatFriendlyDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      final shortMonth = DateFormat('MMM').format(dt) + '.';
      final day = dt.day;
      final suffix = _daySuffix(day);
      final year = dt.year;
      return '$shortMonth $day$suffix, $year';
    } catch (_) {
      return 'Invalid Date';
    }
  }

  String _daySuffix(int day) {
    if (day >= 11 && day <= 13) return 'th';
    switch (day % 10) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
  }

  String _calculateDuration(String start, String end) {
    try {
      final startDate = DateTime.parse(start);
      final endDate = DateTime.parse(end);
      final difference = endDate.difference(startDate);
      
      if (difference.inDays > 1) {
        return '${difference.inDays} days';
      } else if (difference.inDays == 1) {
        return '1 day';
      } else if (difference.inHours > 1) {
        return '${difference.inHours} hours';
      } else if (difference.inHours == 1) {
        return '1 hour';
      } else if (difference.inMinutes > 1) {
        return '${difference.inMinutes} minutes';
      } else if (difference.inMinutes == 1) {
        return '1 minute';
      } else {
        return '';
      }
    } catch (e) {
      return '';
    }
  }
}
