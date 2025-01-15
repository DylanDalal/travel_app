// An Edit Trip form with a Split Trip button. 
// It calls back into the parent’s _performTripSplit() to actually perform the split.
import 'package:flutter/material.dart';
import '../my_trips_section.dart';

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

  /// Called to split the trip at a date. We pass the date to this function.
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: titleController,
            decoration: InputDecoration(
              labelText: "Trip Title",
              border: OutlineInputBorder(),
            ),
          ),
          SizedBox(height: 10),
          ElevatedButton(
            onPressed: onPickDateRange,
            child: Text(
              timeframe == null
                  ? "Select Timeframe"
                  : "${_formatDate(timeframe!.start)} - ${_formatDate(timeframe!.end)}",
            ),
          ),
          SizedBox(height: 10),
          ElevatedButton(
            onPressed: onFetchMetadata,
            child: Text('Fetch and Plot Photo Metadata'),
          ),
          SizedBox(height: 10),
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
          SizedBox(height: 10),
          ElevatedButton(
            onPressed: () async {
              // Show a single-day date picker. Default month = trip's first day:
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
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }
}
