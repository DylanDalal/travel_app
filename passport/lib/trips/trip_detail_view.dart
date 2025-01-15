// trip_detail_view.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // for DateFormat

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
    final endIso   = trip['timeframe']?['end']   ?? '';

    // Friendly date range
    final dateDisplay = (startIso.isNotEmpty && endIso.isNotEmpty)
      ? "${_formatFriendlyDate(startIso)} - ${_formatFriendlyDate(endIso)}"
      : "Unknown Date";

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Back arrow or close
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back),
                onPressed: onBack,
              ),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Text(
            "Trip Dates:",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          Text(dateDisplay),
          SizedBox(height: 24),
          // Additional trip details if needed
        ],
      ),
    );
  }

  /// Convert ISO8601 => "Jan. 15th, 2025"
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
      case 1: return 'st';
      case 2: return 'nd';
      case 3: return 'rd';
      default: return 'th';
    }
  }
}
