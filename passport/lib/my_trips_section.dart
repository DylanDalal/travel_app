import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:photo_manager/photo_manager.dart' as photo;
import 'package:firebase_auth/firebase_auth.dart';
import 'home_screen.dart'; // Ensure Location is imported

class MyTripsSection extends StatefulWidget {
  @override
  _MyTripsSectionState createState() => _MyTripsSectionState();
}

class _MyTripsSectionState extends State<MyTripsSection> {
  late MapboxMap mapboxMap;
  List<Map<String, dynamic>> trips = [];
  List<Location> photoLocations = []; // Define at class level
  bool isAddingNewTrip = false;
  double currentChildSize = 0.25; // Default size for the menu bar


  @override
  void initState() {
    super.initState();
    _loadTrips();
  }

  Future<void> _loadTrips() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final List<dynamic> tripData = userDoc.data()?['trips'] ?? [];

      setState(() {
        trips = tripData.map((trip) => trip as Map<String, dynamic>).toList();
      });
    } catch (e) {
      print('Error loading trips: $e');
    }
  }

  Future<void> fetchAndPlotPhotoMetadata() async {
    final photo.PermissionState state =
        await photo.PhotoManager.requestPermissionExtend();
    if (!state.isAuth) {
      print('Photo access denied');
      return;
    }

    List<photo.AssetPathEntity> albums =
        await photo.PhotoManager.getAssetPathList(
            type: photo.RequestType.image);

    if (albums.isNotEmpty) {
      photo.AssetPathEntity recentAlbum = albums[0];
      List<photo.AssetEntity> userPhotos =
          await recentAlbum.getAssetListPaged(page: 0, size: 100);

      List<Map<String, dynamic>> photoMetadata = [];

      for (photo.AssetEntity photoEntity in userPhotos) {
        if (photoEntity.latitude != null && photoEntity.longitude != null) {
          photoMetadata.add({
            "latitude": photoEntity.latitude,
            "longitude": photoEntity.longitude,
            "timestamp": photoEntity.createDateTime.toIso8601String(),
            "fileName": photoEntity.title ?? "Unknown",
          });

          // Update class-level photoLocations
          photoLocations.add(Location(
            latitude: photoEntity.latitude!,
            longitude: photoEntity.longitude!,
          ));
        }
      }

      await _savePhotoMetadataToFirestore(photoMetadata);
      print("Metadata fetched and saved successfully.");
    } else {
      print('No albums found.');
    }
  }

  Future<void> _savePhotoMetadataToFirestore(
      List<Map<String, dynamic>> photoMetadata) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('No authenticated user.');
      return;
    }

    try {
      final userDoc =
          FirebaseFirestore.instance.collection('users').doc(user.uid);

      await userDoc.set({
        'photos': FieldValue.arrayUnion(photoMetadata),
      }, SetOptions(merge: true));

      print('Photo metadata saved successfully.');
    } catch (e) {
      print('Error saving photo metadata: $e');
    }
  }

  Future<void> _saveTripToFirestore(
    String title,
    DateTimeRange timeframe,
    List<Location> locations,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('No authenticated user.');
      return;
    }

    try {
      final userDoc =
          FirebaseFirestore.instance.collection('users').doc(user.uid);

      final tripData = {
        "id": UniqueKey().toString(),
        "title": title,
        "timeframe": {
          "start": timeframe.start.toIso8601String(),
          "end": timeframe.end.toIso8601String(),
        },
        "locations": locations
            .map((loc) => {
                  "latitude": loc.latitude,
                  "longitude": loc.longitude,
                  "timestamp": DateTime.now().toIso8601String(), // Placeholder
                })
            .toList(),
      };

      // Save trip under 'trips' field
      await userDoc.set({
        'trips': FieldValue.arrayUnion([tripData]),
      }, SetOptions(merge: true));

      print('Trip saved successfully.');
    } catch (e) {
      print('Error saving trip: $e');
    }
  }

    @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Mapbox Globe
        MapWidget(
          cameraOptions: CameraOptions(
            center: Point(coordinates: Position(0, 0)),
            zoom: 2.0,
          ),
          onMapCreated: (map) {
            setState(() {
              mapboxMap = map;
            });
          },
        ),
        // Draggable Scrollable Sheet
        DraggableScrollableSheet(
          initialChildSize: currentChildSize,
          minChildSize: 0.25,
          maxChildSize: 0.75,
          builder: (BuildContext context, ScrollController scrollController) {
            return GestureDetector(
              onTap: () {
                setState(() {
                  currentChildSize = currentChildSize == 0.25 ? 0.75 : 0.25;
                });
              },
              child: AnimatedContainer(
                duration: Duration(milliseconds: 300),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Drag Bar and Title Row
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isAddingNewTrip ? 'Create a Trip' : 'My Trips',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon:
                                Icon(isAddingNewTrip ? Icons.close : Icons.add),
                            onPressed: () {
                              setState(() {
                                isAddingNewTrip = !isAddingNewTrip;
                                if (isAddingNewTrip) {
                                  currentChildSize =
                                      0.75; // Automatically expand to 75%
                                } else {
                                  currentChildSize =
                                      0.25; // Collapse back to initial size
                                }
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    Divider(thickness: 1, color: Colors.grey[300]),
                    Expanded(
                      child: isAddingNewTrip
                          ? _buildTripCreationMenu(scrollController)
                          : _buildTripList(scrollController),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildTripList(ScrollController scrollController) {
    return ListView.builder(
      controller: scrollController,
      itemCount: trips.isEmpty ? 1 : trips.length,
      itemBuilder: (BuildContext context, int index) {
        if (trips.isEmpty) {
          return ListTile(
            title: Center(
              child: Text(
                'No trips yet. Tap the + button to start.',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          );
        }

        final trip = trips[index];
        return Column(
          children: [
            ListTile(
              title: Text(trip['name'] ?? 'Untitled Trip'),
              subtitle: Text(trip['date'] ?? 'Unknown Date'),
              onTap: () {
                // Navigate to trip details
              },
            ),
            Divider(thickness: 1, color: Colors.grey[300]),
          ],
        );
      },
    );
  }


  Widget _buildTripCreationMenu(ScrollController scrollController) {
    final TextEditingController titleController = TextEditingController();
    DateTimeRange? timeframe;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title Input
            TextField(
              controller: titleController,
              decoration: InputDecoration(
                labelText: "Trip Title",
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 10),

            // Date Range Picker
            ElevatedButton(
              onPressed: () async {
                DateTimeRange? pickedRange = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(1900),
                  lastDate: DateTime.now().add(Duration(days: 365)),
                );
                if (pickedRange != null) {
                  setState(() {
                    timeframe = pickedRange;
                  });
                }
              },
              child: Text(
                timeframe == null
                    ? "Select Timeframe"
                    : "${timeframe!.start.toLocal()} - ${timeframe!.end.toLocal()}",
              ),
            ),
            SizedBox(height: 10),

            // Fetch and Plot Photo Metadata Button
            ElevatedButton(
              onPressed: fetchAndPlotPhotoMetadata,
              child: Text('Fetch and Plot Photo Metadata'),
            ),
            SizedBox(height: 10),

            // Save Trip Button
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.isEmpty || timeframe == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Please complete all fields!")),
                  );
                  return;
                }

                // Save trip data
                await _saveTripToFirestore(
                  titleController.text,
                  timeframe!,
                  photoLocations,
                );

                // Refresh trips list
                await _loadTrips();

                setState(() {
                  isAddingNewTrip = false; // Close the creation menu
                });
              },
              child: Text('Save Trip'),
            ),
          ],
        ),
      ),
    );
  }

}