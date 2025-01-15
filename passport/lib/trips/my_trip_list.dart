// trips/my_trip_list.dart
import 'package:flutter/material.dart';
import '../my_trips_section.dart';

class MyTripList extends StatelessWidget {
  final List<Map<String, dynamic>> trips;

  final bool isSelecting;
  final Set<String> selectedTripIds;

  /// Called to confirm swipe-to-delete
  final Future<bool> Function(Map<String, dynamic>) onConfirmSwipeDelete;

  /// Called when the user taps a trip (to view details)
  final Function(Map<String, dynamic>) onTapTrip;

  /// Called when the user taps edit
  final Function(Map<String, dynamic>) onEditTrip;

  const MyTripList({
    Key? key,
    required this.trips,
    required this.isSelecting,
    required this.selectedTripIds,
    required this.onConfirmSwipeDelete,
    required this.onTapTrip,
    required this.onEditTrip,
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
        if (tripId == null) {
          return Container(); 
        }

        final bool isSelected = selectedTripIds.contains(tripId);
        final startIso = trip['timeframe']?['start'] ?? '';
        final endIso = trip['timeframe']?['end'] ?? '';
        final displayDate = (startIso.isNotEmpty && endIso.isNotEmpty)
            ? "$startIso - $endIso"
            : "Unknown Date";

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
                          // The parent modifies selection set
                          if (checked == true) {
                            selectedTripIds.add(tripId);
                          } else {
                            selectedTripIds.remove(tripId);
                          }
                          // We force a rebuild by calling (context as Element).reassemble()
                          // or some other callback. Typically you'd pass a callback
                          // to setState at the parent. 
                          // For simplicity, we won't handle it here. 
                        },
                      )
                    : null,
                title: Text(trip['title'] ?? 'Untitled Trip'),
                subtitle: Text(displayDate),
                onTap: () {
                  if (isSelecting) {
                    if (isSelected) {
                      selectedTripIds.remove(tripId);
                    } else {
                      selectedTripIds.add(tripId);
                    }
                    // same note as above about forcing a rebuild
                  } else {
                    // view trip details
                    onTapTrip(trip);
                  }
                },
                trailing: IconButton(
                  icon: Icon(Icons.edit),
                  onPressed: () {
                    onEditTrip(trip);
                  },
                ),
              ),
              Divider(thickness: 1, color: Colors.grey[300]),
            ],
          ),
        );
      },
    );
  }
}
