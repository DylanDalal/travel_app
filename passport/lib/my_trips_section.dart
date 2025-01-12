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
  late MapboxMap mapboxMap; // Mapbox map instance
  List<Map<String, dynamic>> trips = []; // List of trips fetched from Firestore
  List<Location> photoLocations = []; // Locations extracted from photo metadata
  bool isAddingNewTrip = false; // Toggles between trip list and creation menu
  double currentChildSize = 0.25; // Default size for the draggable menu bar
  final TextEditingController titleController = TextEditingController(); // Controller for the trip title input field
  DateTimeRange? timeframe; // Selected timeframe for the trip

  @override
  void initState() {
    super.initState();
    _loadTrips(); // Load trips from Firestore on widget initialization
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
        await photo.PhotoManager.getAssetPathList(type: photo.RequestType.image);

    if (albums.isNotEmpty) {
      photo.AssetPathEntity recentAlbum = albums[0];
      List<photo.AssetEntity> userPhotos =
          await recentAlbum.getAssetListPaged(page: 0, size: 100);

      if (userPhotos.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("No photos found in timeframe selected.")),
        );
        return;
      }

      for (photo.AssetEntity photoEntity in userPhotos) {
        if (photoEntity.latitude != null && photoEntity.longitude != null) {
          print("Photo: ${photoEntity.title}, "
              "Latitude: ${photoEntity.latitude}, "
              "Longitude: ${photoEntity.longitude}");
          photoLocations.add(Location(
            latitude: photoEntity.latitude!,
            longitude: photoEntity.longitude!,
          ));
        }
      }

      print("Metadata fetched successfully.");
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("No photos found in timeframe selected.")),
      );
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
                  "timestamp": DateTime.now().toIso8601String(),
                })
            .toList(),
      };

      await userDoc.set({
        'trips': FieldValue.arrayUnion([tripData]),
      }, SetOptions(merge: true));

      print('Trip saved successfully.');
    } catch (e) {
      print('Error saving trip: $e');
    }
  }

  Future<void> _updateTripInFirestore(
    String tripId,
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
        "id": tripId,
        "title": title,
        "timeframe": {
          "start": timeframe.start.toIso8601String(),
          "end": timeframe.end.toIso8601String(),
        },
        "locations": locations
            .map((loc) => {
                  "latitude": loc.latitude,
                  "longitude": loc.longitude,
                  "timestamp": DateTime.now().toIso8601String(),
                })
            .toList(),
      };

      final existingTrips = trips
          .where((trip) => trip['id'] != tripId)
          .toList(); // Filter out the current trip
      existingTrips.add(tripData);

      await userDoc.set({
        'trips': existingTrips,
      });

      print('Trip updated successfully.');
    } catch (e) {
      print('Error updating trip: $e');
    }
  }

  Future<void> _saveOrUpdateTrip() async {
    if (titleController.text.isEmpty || timeframe == null) {
      String error = "Please complete all fields!\n";
      if (titleController.text.isEmpty) error += " - Trip Title is empty\n";
      if (timeframe == null) error += " - Timeframe is not selected";

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
      return;
    }

    final existingTrip = trips.firstWhere(
      (trip) => trip['title'] == titleController.text,
      orElse: () => {}, // Fixed to return an empty map
    );

    if (existingTrip.isNotEmpty) {
      await _updateTripInFirestore(
        existingTrip['id'],
        titleController.text,
        timeframe!,
        photoLocations,
      );
    } else {
      await _saveTripToFirestore(
        titleController.text,
        timeframe!,
        photoLocations,
      );
    }

    await _loadTrips();
    setState(() {
      isAddingNewTrip = false;
    });
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
              title: Text(trip['title'] ?? 'Untitled Trip'),
              subtitle: Text(trip['timeframe']?['start'] ?? 'Unknown Date'),
              trailing: IconButton(
                icon: Icon(Icons.edit),
                onPressed: () {
                  _editTrip(trip);
                },
              ),
            ),
            Divider(thickness: 1, color: Colors.grey[300]),
          ],
        );
      },
    );
  }

  void _editTrip(Map<String, dynamic> trip) {
    setState(() {
      titleController.text = trip['title'] ?? '';
      final start = DateTime.parse(trip['timeframe']['start']);
      final end = DateTime.parse(trip['timeframe']['end']);
      timeframe = DateTimeRange(start: start, end: end);

      isAddingNewTrip = true;
      currentChildSize = 0.75;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
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
        DraggableScrollableSheet(
          initialChildSize: currentChildSize,
          minChildSize: 0.25,
          maxChildSize: 0.75,
          builder: (BuildContext context, ScrollController scrollController) {
            return GestureDetector(
              onTap: () {
                setState(() {
                  currentChildSize =
                      currentChildSize == 0.25 ? 0.75 : 0.25;
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
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isAddingNewTrip
                                ? 'Create a Trip'
                                : 'My Trips',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              isAddingNewTrip ? Icons.close : Icons.add,
                            ),
                            onPressed: () {
                              setState(() {
                                isAddingNewTrip = !isAddingNewTrip;
                                currentChildSize =
                                    isAddingNewTrip ? 0.75 : 0.25;
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
}
