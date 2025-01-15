import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:photo_manager/photo_manager.dart' as photo;
import 'package:firebase_auth/firebase_auth.dart';
import 'home_screen.dart';
import 'dart:typed_data';
import 'package:flutter/services.dart'; // For rootBundle


class MyTripsSection extends StatefulWidget {
  @override
  _MyTripsSectionState createState() => _MyTripsSectionState();
}

class _MyTripsSectionState extends State<MyTripsSection> {
  bool isAddingNewTrip = false;
  double currentChildSize = 0.25;
  DateTimeRange? timeframe;
  final TextEditingController titleController = TextEditingController();
  late MapboxMap mapboxMap;
  late PointAnnotationManager pointAnnotationManager;
  bool isPointAnnotationManagerInitialized = false;
  List<Map<String, dynamic>> trips = [];
  List<Location> photoLocations = [];
  String? editingTripId;

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

      print('Loaded trips from Firestore: $tripData');

      setState(() {
        trips = tripData.map((trip) => trip as Map<String, dynamic>).toList();
      });
    } catch (e) {
      print('Error loading trips: $e');
    }
  }

  Future<void> fetchAndPlotPhotoMetadata() async {
    if (timeframe == null) {
      print('No timeframe selected. Please select a timeframe first.');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a timeframe first.')),
      );
      return;
    }

    final photo.PermissionState state =
        await photo.PhotoManager.requestPermissionExtend();
    if (!state.isAuth) {
      print('Photo access denied.');
      return;
    }

    try {
      List<photo.AssetPathEntity> albums =
          await photo.PhotoManager.getAssetPathList(type: photo.RequestType.image);

      if (albums.isEmpty) {
        print('No photo albums found.');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No photo albums found.')),
        );
        return;
      }

      photo.AssetPathEntity recentAlbum = albums[0];
      List<photo.AssetEntity> userPhotos =
          await recentAlbum.getAssetListPaged(page: 0, size: 100);

      if (userPhotos.isEmpty) {
        print('No photos found in the album.');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No photos found in the album.')),
        );
        return;
      }

      photoLocations.clear();
      DateTime start = timeframe!.start;
      DateTime end = timeframe!.end;

      for (photo.AssetEntity photoEntity in userPhotos) {
        if (photoEntity.latitude != null &&
            photoEntity.longitude != null &&
            photoEntity.createDateTime.isAfter(start) &&
            photoEntity.createDateTime.isBefore(end)) {
          photoLocations.add(Location(
            latitude: photoEntity.latitude!,
            longitude: photoEntity.longitude!,
            timestamp: photoEntity.createDateTime.toIso8601String(),
          ));

          print("Photo: ${photoEntity.title}, "
              "Latitude: ${photoEntity.latitude}, "
              "Longitude: ${photoEntity.longitude}, "
              "Timestamp: ${photoEntity.createDateTime.toIso8601String()}");
        }
      }

      if (photoLocations.isEmpty) {
        print('No photos found in the selected timeframe.');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No photos found in the selected timeframe.')),
        );
      } else {
        print("Metadata fetched successfully for this trip.");
        _plotLocationsOnMap();
      }
    } catch (e) {
      print('Error fetching photo metadata: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching photo metadata.')),
      );
    }
  }

  void _onMapCreated(MapboxMap map) {
    print('onMapCreated called');
    setState(() {
      mapboxMap = map;
    });

    map.annotations.createPointAnnotationManager().then((manager) {
      setState(() {
        pointAnnotationManager = manager;
        isPointAnnotationManagerInitialized = true;
        print('PointAnnotationManager initialized.');
        _plotLocationsOnMap();
      });
    }).catchError((error) {
      print('Error initializing PointAnnotationManager: $error');
    });
  }

 Future<void> _plotLocationsOnMap() async {
  print('plotLocationsOnMap called');
  if (!isPointAnnotationManagerInitialized) {
    print('PointAnnotationManager is not initialized yet.');
    return;
  }

  try {
    pointAnnotationManager.deleteAll();
    print('Cleared existing markers.');

    for (var location in photoLocations) {
      if (location.latitude == 0 || location.longitude == 0) {
        print('Skipping invalid location: Latitude ${location.latitude}, Longitude ${location.longitude}');
        continue;
      }

      try {
          final ByteData bytes = await rootBundle.load('lib/assets/pin.png');
          final Uint8List imageData = bytes.buffer.asUint8List();

          pointAnnotationManager?.create(
            PointAnnotationOptions(
              geometry: Point(
                coordinates: Position(location.longitude, location.latitude),
              ),
              image: imageData,
              iconSize: 0.05,
            ),
          );
        print('Marker created at (${location.latitude}, ${location.longitude}).');
      } catch (e) {
        print('Error creating marker: $e');
      }
    }

    if (photoLocations.isNotEmpty) {
      mapboxMap.setCamera(CameraOptions(
        center: Point(
          coordinates: Position(
            photoLocations.first.longitude,
            photoLocations.first.latitude,
          ),
        ),
        zoom: 1.0, // Higher zoom level
      ));
    }

     // Force map redraw
    print('Locations plotted successfully.');
  } catch (e) {
    print('Error plotting locations: $e');
  }





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
          onMapCreated: _onMapCreated,
        ),
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
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isAddingNewTrip ? 'Create/Edit Trip' : 'My Trips',
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
                                if (isAddingNewTrip) {
                                  titleController.clear();
                                  timeframe = null;
                                  photoLocations.clear();
                                  editingTripId = null;
                                }
                                isAddingNewTrip = !isAddingNewTrip;
                                currentChildSize = isAddingNewTrip ? 0.75 : 0.25;
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

  Widget _buildTripCreationMenu(ScrollController scrollController) {
    return SingleChildScrollView(
      child: Padding(
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
            ElevatedButton(
              onPressed: fetchAndPlotPhotoMetadata,
              child: Text('Fetch and Plot Photo Metadata'),
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.isEmpty || timeframe == null) {
                  String error = "Please complete all fields!\n";
                  if (titleController.text.isEmpty) error += " - Trip Title is empty\n";
                  if (timeframe == null) error += " - Timeframe is not selected";

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(error)),
                  );
                  return;
                }

                await _saveTripToFirestore(
                  titleController.text,
                  timeframe!,
                  photoLocations,
                );

                await _loadTrips();
                setState(() {
                  titleController.clear();
                  timeframe = null;
                  photoLocations.clear();
                  isAddingNewTrip = false;
                });
              },
              child: Text('Save Trip'),
            ),
          ],
        ),
      ),
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
              title: Text(trip['title'] ?? 'Untitled Trip'),
              subtitle: Text(trip['timeframe']?['start'] ?? 'Unknown Date'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(Icons.edit),
                    onPressed: () {
                      setState(() {
                        titleController.text = trip['title'] ?? '';
                        final start = DateTime.parse(trip['timeframe']['start']);
                        final end = DateTime.parse(trip['timeframe']['end']);
                        timeframe = DateTimeRange(start: start, end: end);
                        editingTripId = trip['id'];
                        isAddingNewTrip = true;
                        currentChildSize = 0.75;
                      });
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.delete),
                    onPressed: () {
                      _confirmDeleteTrip(trip['id']);
                    },
                  ),
                ],
              ),
            ),
            Divider(thickness: 1, color: Colors.grey[300]),
          ],
        );
      },
    );
  }

  void _confirmDeleteTrip(String tripId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Confirm Delete"),
          content: Text("Are you sure you want to delete this trip?"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteTrip(tripId);
              },
              child: Text("Delete"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteTrip(String tripId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('No authenticated user.');
      return;
    }

    try {
      final userDoc = FirebaseFirestore.instance.collection('users').doc(user.uid);
      final updatedTrips = trips.where((trip) => trip['id'] != tripId).toList();

      await userDoc.set({'trips': updatedTrips}, SetOptions(merge: true));

      setState(() {
        trips = updatedTrips;
      });

      print('Trip deleted successfully.');
    } catch (e) {
      print('Error deleting trip: $e');
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
      final userDoc = FirebaseFirestore.instance.collection('users').doc(user.uid);

      if (editingTripId != null) {
        final updatedTrips = trips.map((trip) {
          if (trip['id'] == editingTripId) {
            return {
              "id": editingTripId,
              "title": title,
              "timeframe": {
                "start": timeframe.start.toIso8601String(),
                "end": timeframe.end.toIso8601String(),
              },
              "locations": locations
                  .map((loc) => {
                        "latitude": loc.latitude,
                        "longitude": loc.longitude,
                        "timestamp": loc.timestamp,
                      })
                  .toList(),
            };
          }
          return trip;
        }).toList();

        await userDoc.set({'trips': updatedTrips}, SetOptions(merge: true));
        print('Trip updated successfully.');
      } else {
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
                    "timestamp": loc.timestamp,
                  })
              .toList(),
        };

        await userDoc.set({
          'trips': FieldValue.arrayUnion([tripData]),
        }, SetOptions(merge: true));

        print('Trip saved successfully.');
      }

      await _loadTrips();
    } catch (e) {
      print('Error saving trip: $e');
    }
  }
}

class Location {
  final double latitude;
  final double longitude;
  final String timestamp;

  Location({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
  });
}
