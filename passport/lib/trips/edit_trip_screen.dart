// lib/trips/edit_trip_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart' show VoidCallback;
import '../classes.dart'; // For Location

class EditTripScreen extends StatelessWidget {
  final TextEditingController titleController;
  final DateTimeRange? timeframe;
  final List<Location> photoLocations;

  /// Called when user wants to pick a date range
  final VoidCallback onPickDateRange;

  /// Called when user wants to fetch & plot photos
  final VoidCallback onFetchMetadata;

  /// Called to actually update the trip
  final Function(String, DateTimeRange, List<Location>) onUpdateTrip;

  /// Called to split the trip at a date (we pass the chosen date to this function).
  final Future<void> Function(DateTime) onSplitDate;

  const EditTripScreen({
    Key? key,
    required this.titleController,
    required this.timeframe,
    required this.photoLocations,
    required this.onPickDateRange,
    required this.onFetchMetadata,
    required this.onUpdateTrip,
    required this.onSplitDate,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Build a friendly date string (e.g. "Jan. 15th, 2025 - Jan. 20th, 2025")
    final timeframeDisplay = (timeframe == null)
        ? "Select Timeframe"
        : "${_formatFriendlyDate(timeframe!.start)} - ${_formatFriendlyDate(timeframe!.end)}";

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Title field
          TextField(
            controller: titleController,
            decoration: InputDecoration(
              labelText: "Trip Title",
              border: OutlineInputBorder(),
            ),
          ),
          SizedBox(height: 10),

          // Pick date range
          ElevatedButton(
            onPressed: onPickDateRange,
            child: Text(timeframeDisplay),
          ),
          SizedBox(height: 10),

          // Fetch & Plot
          ElevatedButton(
            onPressed: onFetchMetadata,
            child: Text('Fetch and Plot Photo Metadata'),
          ),
          SizedBox(height: 10),

          // Split Trip first
          ElevatedButton(
            onPressed: () async {
              if (timeframe == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("No trip timeframe set.")),
                );
                return;
              }

              final DateTime initialSplitDate = timeframe!.start; 
              final picked = await showDatePicker(
                context: context,
                initialDate: initialSplitDate,
                firstDate: DateTime(
                  initialSplitDate.year,
                  initialSplitDate.month,
                ),
                lastDate: DateTime(2100),
              );
              if (picked != null) {
                await onSplitDate(picked);
              }
            },
            child: Text('Split Trip'),
          ),
          SizedBox(height: 10),

          // Update Trip
          ElevatedButton(
            onPressed: () {
              if (titleController.text.isEmpty || timeframe == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Please fill all fields.")),
                );
                return;
              }
              onUpdateTrip(titleController.text, timeframe!, photoLocations);
            },
            child: Text('Update Trip'),
          ),
        ],
      ),
    );
  }

  /// e.g. "Jan. 15th, 2025"
  String _formatFriendlyDate(DateTime date) {
    final shortMonth = DateFormat('MMM').format(date) + '.';
    final day = date.day;
    final suffix = _daySuffix(day);
    final year = date.year;
    return '$shortMonth $day$suffix, $year';
  }

  String _daySuffix(int day) {
    // 11th, 12th, 13th => 'th'
    if (day >= 11 && day <= 13) return 'th';
    switch (day % 10) {
      case 1: return 'st';
      case 2: return 'nd';
      case 3: return 'rd';
      default: return 'th';
    }
  }
}
