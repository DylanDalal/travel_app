// A simple stateless (or stateful) widget showing the Create Trip form.
// It receives callbacks from the parent widget (my_trips_section) so that 
// the user’s actions can create trips in Firestore.

import 'package:flutter/material.dart';
import '../my_trips_section.dart';
import '../classes.dart'; // Import Location class

class CreateTripScreen extends StatelessWidget {
  final TextEditingController titleController;
  final DateTimeRange? timeframe;
  final List<Location> photoLocations;

  final VoidCallback onPickDateRange; // call to pick date range
  final VoidCallback onFetchMetadata; // fetch & plot photos
  final Function(String, DateTimeRange, List<Location>) onSaveTrip;

  const CreateTripScreen({
    Key? key,
    required this.titleController,
    required this.timeframe,
    required this.photoLocations,
    required this.onPickDateRange,
    required this.onFetchMetadata,
    required this.onSaveTrip,
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
              onSaveTrip(titleController.text, timeframe!, photoLocations);
            },
            child: Text('Save Trip'),
          ),
        ],
      ),
    );
  }

  // Minimal date formatting for the button
  String _formatDate(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }
}
