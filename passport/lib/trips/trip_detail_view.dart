// A simple read-only view for a single trip’s details.
// Will be where we do a lot of logic in the future, showing photos, reviews, etc.

import 'package:flutter/material.dart';

class TripDetailView extends StatelessWidget {
  final Map<String, dynamic> trip;
  final VoidCallback onBack;

  const TripDetailView({
    Key? key,
    required this.trip,
    required this.onBack,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final title = trip['title'] ?? 'Untitled Trip';
    final startIso = trip['timeframe']?['start'] ?? '';
    final endIso = trip['timeframe']?['end'] ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back),
                onPressed: onBack,
              ),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Text(
            "Trip Dates:",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          Text("$startIso - $endIso"), 
          // In a real app, you'd parse & format nicely or reuse a helper
          SizedBox(height: 24),
        ],
      ),
    );
  }
}
