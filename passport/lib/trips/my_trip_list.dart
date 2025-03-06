import 'package:flutter/material.dart';
import 'package:intl/intl.dart';  // for DateFormat
import '../classes.dart';        // if needed for Location
// ... any other imports

class MyTripList extends StatelessWidget {
  final List<Map<String, dynamic>> trips;
  final bool isSelecting;
  final Set<String> selectedTripIds;
  final Future<bool> Function(Map<String, dynamic>) onConfirmSwipeDelete;
  final Function(Map<String, dynamic>) onTapTrip;
  final Function(Map<String, dynamic>) onEditTrip;

  /// Callback from parent to toggle a trip's selection
  final Function(String tripId, bool isSelected) onToggleSelection;

  const MyTripList({
    Key? key,
    required this.trips,
    required this.isSelecting,
    required this.selectedTripIds,
    required this.onConfirmSwipeDelete,
    required this.onTapTrip,
    required this.onEditTrip,
    required this.onToggleSelection,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (trips.isEmpty) {
      return ListView(
        children: [
          ListTile(
            title: Center(
              child: Text(
                'No trips yet. Tap the + button to start.',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          )
        ],
      );
    }

    return ListView.builder(
      itemCount: trips.length,
      itemBuilder: (BuildContext context, int index) {
        final trip = trips[index];
        final tripId = trip['id'] as String?;
        if (tripId == null) return Container();

        final bool isSelected = selectedTripIds.contains(tripId);

        // Extract the ISO strings
        final startIso = trip['timeframe']?['start'] ?? '';
        final endIso = trip['timeframe']?['end'] ?? '';

        // Format the dates
        final String startDate = _formatFriendlyDate(startIso);
        final String endDate = _formatFriendlyDate(endIso);

        // Set display date based on whether dates are the same
        final displayDate = (startIso.isNotEmpty && endIso.isNotEmpty)
            ? (startDate == endDate)
                ? startDate  // If same date, just show one
                : '$startDate - $endDate'  // If different, show range
            : 'Unknown Date';

        return Dismissible(
          key: ValueKey(tripId),
          direction: DismissDirection.startToEnd,
          confirmDismiss: (dir) => onConfirmSwipeDelete(trip),
          background: Container(
            color: Colors.red,
            alignment: Alignment.centerLeft,
            padding: EdgeInsets.only(left: 20.0),
            child: Row(
              children: [
                Icon(Icons.delete, color: Colors.white),
                SizedBox(width: 10),
                Text(
                  'DELETE',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          child: Column(
            children: [
              ListTile(
                leading: isSelecting
                    ? Checkbox(
                        value: isSelected,
                        onChanged: (checked) {
                          onToggleSelection(tripId, checked ?? false);
                        },
                      )
                    : null,
                title: Text(trip['title'] ?? 'Untitled Trip'),
                subtitle: Text(displayDate),
                onTap: () {
                  if (isSelecting) {
                    onToggleSelection(tripId, !isSelected);
                  } else {
                    onTapTrip(trip);
                  }
                },
                trailing: IconButton(
                  icon: Icon(Icons.edit),
                  onPressed: () => onEditTrip(trip),
                ),
              ),
              Divider(thickness: 1, color: Colors.grey[300]),
            ],
          ),
        );
      },
    );
  }

  /// Converts an ISO8601 string (e.g. "2025-01-15T00:00:00.000")
  /// into "Jan. 15th, 2025".
  String _formatFriendlyDate(String isoString) {
    if (isoString.isEmpty) return 'Unknown';
    try {
      final dt = DateTime.parse(isoString);

      // Abbreviated month: "Jan." 
      final shortMonth = DateFormat('MMM').format(dt) + '.'; // e.g. "Jan."
      final day = dt.day;
      final suffix = _daySuffix(day);     // st, nd, rd, th
      final year = dt.year;
      return '$shortMonth $day$suffix, $year';
    } catch (_) {
      return 'Invalid Date';
    }
  }

  /// Returns "st", "nd", "rd", or "th" depending on day number.
  String _daySuffix(int day) {
    if (day >= 11 && day <= 13) {
      return 'th';
    }
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
}
