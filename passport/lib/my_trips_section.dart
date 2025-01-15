import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:photo_manager/photo_manager.dart' as photo;
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:typed_data';
import 'package:flutter/services.dart';
// NEW import for formatting
import 'package:intl/intl.dart';

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
  late PointAnnotationManager pointAnnotationManager; // Declare without initializing
  bool isPointAnnotationManagerInitialized = false;
  List<Map<String, dynamic>> trips = [];
  List<Location> photoLocations = [];
  String? editingTripId;

  bool isViewingTrip = false;
  Map<String, dynamic>? selectedTrip;

  bool isSelecting = false;
  Set<String> selectedTripIds = {};

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

  /// Helper function to format an ISO date (e.g. 2024-04-08T00:00:00.000)
  /// into a nice "April 08th, 2024" display.
  String _formatDateString(String isoString) {
    try {
      DateTime dateObj = DateTime.parse(isoString);
      return _formatDate(dateObj);
    } catch (_) {
      return isoString; // fallback if parse fails
    }
  }

  /// A helper that takes a DateTime and returns "April 08th, 2024".
  /// We generate the correct suffix (st, nd, rd, th) based on the day number.
  String _formatDate(DateTime date) {
    final day = date.day;
    final suffix = _daySuffix(day);
    final month = DateFormat('MMMM').format(date); // e.g. April
    final year = date.year;
    return '$month $day$suffix, $year';
  }

  /// Returns "st", "nd", "rd", or "th" depending on the day.
  String _daySuffix(int day) {
    // Special case for 11th, 12th, 13th
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

  Future<void> fetchAndPlotPhotoMetadata() async {
    if (timeframe == null) {
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
      // Get the list of photo albums
      List<photo.AssetPathEntity> albums =
          await photo.PhotoManager.getAssetPathList(type: photo.RequestType.image);

      if (albums.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No photo albums found.')),
        );
        return;
      }

      // Fetch photos from the first album (e.g., Recent)
      photo.AssetPathEntity recentAlbum = albums[0];
      List<photo.AssetEntity> userPhotos =
          await recentAlbum.getAssetListPaged(page: 0, size: 100);

      if (userPhotos.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No photos found in the album.')),
        );
        return;
      }

      // Clear existing photoLocations for the trip
      photoLocations.clear();

      // Filter photos by timeframe and geotagged information
      DateTime start = timeframe!.start;
      DateTime end = timeframe!.end;

      for (photo.AssetEntity photoEntity in userPhotos) {
        if (photoEntity.latitude != null &&
            photoEntity.longitude != null &&
            photoEntity.createDateTime.isAfter(start) &&
            photoEntity.createDateTime.isBefore(end)) {
          // Add photo metadata to the trip's photoLocations
          photoLocations.add(Location(
            latitude: photoEntity.latitude!,
            longitude: photoEntity.longitude!,
            timestamp: photoEntity.createDateTime.toIso8601String(),
          ));
        }
      }

      if (photoLocations.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No photos found in the selected timeframe.')),
        );
      } else {
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
    setState(() {
      mapboxMap = map;
    });

    // Initialize PointAnnotationManager asynchronously
    mapboxMap.annotations.createPointAnnotationManager().then((manager) {
      setState(() {
        pointAnnotationManager = manager;
        isPointAnnotationManagerInitialized = true;
        _plotLocationsOnMap();
      });
    }).catchError((error) {
      print('Error initializing PointAnnotationManager: $error');
    });
  });
}

  Future<void> _plotLocationsOnMap() async {
    if (!isPointAnnotationManagerInitialized) {
      return;
    }

    try {
      pointAnnotationManager.deleteAll();

      for (var location in photoLocations) {
        if (location.latitude == 0 || location.longitude == 0) {
          continue;
        }

        try {
          final ByteData bytes = await rootBundle.load('lib/assets/pin.png');
          final Uint8List imageData = bytes.buffer.asUint8List();

          pointAnnotationManager.create(
            PointAnnotationOptions(
              geometry: Point(
                coordinates: Position(location.longitude, location.latitude),
              ),
              image: imageData,
              iconSize: 0.05,
            ),
          );
        } catch (e) {
          print('Error creating marker: $e');
        }
      }

      if (photoLocations.isNotEmpty) {
        mapboxMap.setCamera(
          CameraOptions(
            center: Point(
              coordinates: Position(
                photoLocations.first.longitude,
                photoLocations.first.latitude,
              ),
            ),
            zoom: 1.0,
          ),
        );
      }
    } catch (e) {
      print('Error plotting locations: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // The Map
        MapWidget(
          cameraOptions: CameraOptions(
            center: Point(coordinates: Position(0, 0)),
            zoom: 2.0,
          ),
          onMapCreated: (map) {
            setState(() {
              mapboxMap = map;

              // Initialize the annotation manager and plot locations
              _plotLocationsOnMap();
            });
          },
        ),
        // The Draggable sheet on top
        DraggableScrollableSheet(
          initialChildSize: currentChildSize,
          minChildSize: 0.25,
          maxChildSize: 0.5, // can go up to half-screen
          builder: (BuildContext context, ScrollController scrollController) {
            return GestureDetector(
              onTap: () {
                setState(() {
                  // Toggle between 25% and 50%
                  currentChildSize = (currentChildSize == 0.25) ? 0.5 : 0.25;
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
                    // Top row
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: _buildTopRow(),
                    ),
                    Divider(thickness: 1, color: Colors.grey[300]),
                    // The main content area
                    Expanded(
                      child: _buildChildContent(scrollController),
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

  /// Builds the top row in the Draggable sheet
  Widget _buildTopRow() {
    if (isSelecting) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton(
            onPressed: _mergeSelectedTrips,
            child: Text(
              "Merge",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                isSelecting = false;
                selectedTripIds.clear();
              });
            },
            child: Text(
              "Deselect",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          TextButton(
            onPressed:
                selectedTripIds.isNotEmpty ? _confirmDeleteSelected : null,
            child: Text(
              "Delete",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: selectedTripIds.isNotEmpty ? Colors.red : Colors.grey,
              ),
            ),
          ),
        ],
      );
    }

    // Otherwise, normal header row
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          _buildHeaderTitle(),
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        Row(
          children: [
            if (!isAddingNewTrip && !isViewingTrip)
              TextButton(
                onPressed: () {
                  setState(() {
                    isSelecting = true;
                    selectedTripIds.clear();
                  });
                },
                child: Text("Select"),
              ),
            IconButton(
              icon: Icon(isAddingNewTrip ? Icons.close : Icons.add),
              onPressed: () {
                setState(() {
                  if (isAddingNewTrip) {
                    titleController.clear();
                    timeframe = null;
                    photoLocations.clear();
                    editingTripId = null;
                  }
                  isAddingNewTrip = !isAddingNewTrip;
                  isViewingTrip = false;
                  selectedTrip = null;
                  currentChildSize = isAddingNewTrip ? 0.5 : 0.25;
                });
              },
            ),
          ],
        ),
      ],
    );
  }

  String _buildHeaderTitle() {
    if (isAddingNewTrip) return 'Create/Edit Trip';
    if (isViewingTrip) return 'Trip Details';
    return 'My Trips';
  }

  Widget _buildChildContent(ScrollController scrollController) {
    if (isAddingNewTrip) {
      return _buildTripCreationMenu(scrollController);
    } else if (isViewingTrip && selectedTrip != null) {
      return _buildTripDetailView(scrollController);
    } else {
      return _buildTripList(scrollController);
    }
  }

  Widget _buildTripDetailView(ScrollController scrollController) {
    if (selectedTrip == null) {
      return Center(child: Text("No trip selected"));
    }

    final trip = selectedTrip!;
    final String title = trip['title'] ?? 'Untitled Trip';

    // Parse & format start and end
    final String rawStart = trip['timeframe']?['start'] ?? '';
    final String rawEnd = trip['timeframe']?['end'] ?? '';
    final String formattedStart = rawStart.isEmpty ? 'Unknown' : _formatDateString(rawStart);
    final String formattedEnd   = rawEnd.isEmpty ? 'Unknown'  : _formatDateString(rawEnd);

    return SingleChildScrollView(
      controller: scrollController,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Back button + Title
            Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back),
                  onPressed: () {
                    setState(() {
                      isViewingTrip = false;
                      selectedTrip = null;
                      currentChildSize = 0.25;
                    });
                  },
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
            Text("$formattedStart - $formattedEnd"),
            SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildTripCreationMenu(ScrollController scrollController) {
    return SingleChildScrollView(
      controller: scrollController,
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
                    : "${_formatDate(timeframe!.start)} - ${_formatDate(timeframe!.end)}",
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
                  if (titleController.text.isEmpty) {
                    error += " - Trip Title is empty\n";
                  }
                  if (timeframe == null) {
                    error += " - Timeframe is not selected";
                  }

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
                  _clearFields(); // Clear fields after saving
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

  /// The main My Trips list
  Widget _buildTripList(ScrollController scrollController) {
    if (trips.isEmpty) {
      return ListView(
        controller: scrollController,
        children: [
          ListTile(
            title: Center(
              child: Text(
                'No trips yet. Tap the + button to start.',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      controller: scrollController,
      itemCount: trips.length,
      itemBuilder: (BuildContext context, int index) {
        final trip = trips[index];
        final tripId = trip['id'] as String?;
        if (tripId == null) {
          return Container();
        }

        final isSelected = selectedTripIds.contains(tripId);

        // Parse & format date
        final String startIso = trip['timeframe']?['start'] ?? '';
        final String endIso = trip['timeframe']?['end'] ?? '';
        final String displayDate = (startIso.isNotEmpty && endIso.isNotEmpty)
            ? '${_formatDateString(startIso)} - ${_formatDateString(endIso)}'
            : 'Unknown Date';

        return Dismissible(
          key: ValueKey(tripId),
          direction: DismissDirection.startToEnd,
          confirmDismiss: (direction) => _confirmSwipeDelete(trip),
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
                        onChanged: (bool? checked) {
                          setState(() {
                            if (checked == true) {
                              selectedTripIds.add(tripId);
                            } else {
                              selectedTripIds.remove(tripId);
                            }
                          });
                        },
                      )
                    : null,
                title: Text(trip['title'] ?? 'Untitled Trip'),
                // Now show "start - end" in friendly format
                subtitle: Text(displayDate),
                onTap: () {
                  if (isSelecting) {
                    setState(() {
                      if (isSelected) {
                        selectedTripIds.remove(tripId);
                      } else {
                        selectedTripIds.add(tripId);
                      }
                    });
                  } else {
                    setState(() {
                      selectedTrip = trip;
                      isViewingTrip = true;
                      isAddingNewTrip = false;
                      currentChildSize = 0.5; // show half screen
                    });
                  }
                },
                // No trash icon - only swipe to delete
                trailing: IconButton(
                  icon: Icon(Icons.edit),
                  onPressed: () {
                    setState(() {
                      titleController.text = trip['title'] ?? '';
                      final start = DateTime.parse(startIso);
                      final end = DateTime.parse(endIso);
                      timeframe = DateTimeRange(start: start, end: end);
                      editingTripId = tripId;
                      isAddingNewTrip = true;
                      isViewingTrip = false;
                      currentChildSize = 0.5;
                    });
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

  Future<bool> _confirmSwipeDelete(Map<String, dynamic> trip) async {
    final tripId = trip['id'];
    final tripTitle = trip['title'] ?? 'Untitled Trip';

    return await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Confirm Delete"),
          content: Text("Are you sure you want to delete the trip '$tripTitle'?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false), // Cancel
              child: Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: Text("Delete", style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    ).then((value) {
      if (value == true) {
        _deleteTrip(tripId);
      }
      return value ?? false;
    });
  }

  Future<void> _deleteTrip(String tripId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }

    try {
      final userDoc = FirebaseFirestore.instance.collection('users').doc(user.uid);
      final updatedTrips = trips.where((trip) => trip['id'] != tripId).toList();

      await userDoc.set({'trips': updatedTrips}, SetOptions(merge: true));
      setState(() {
        trips = updatedTrips;
        selectedTripIds.remove(tripId);
      });
    } catch (e) {
      print('Error deleting trip: $e');
    }
  }

  void _confirmDeleteSelected() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final count = selectedTripIds.length;
        return AlertDialog(
          title: Text("Confirm Delete"),
          content: Text(
            "Are you sure you want to delete $count selected "
            "${count == 1 ? 'trip' : 'trips'}?",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(), // Cancel
              child: Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteMultipleTrips(selectedTripIds);
              },
              child: Text("Delete", style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteMultipleTrips(Set<String> toDelete) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final userDoc = FirebaseFirestore.instance.collection('users').doc(user.uid);
      final updatedTrips =
          trips.where((trip) => !toDelete.contains(trip['id'])).toList();

      await userDoc.set({'trips': updatedTrips}, SetOptions(merge: true));
      setState(() {
        trips = updatedTrips;
        selectedTripIds.clear();
        isSelecting = false;
      });
    } catch (e) {
      print('Error deleting multiple trips: $e');
    }
  }

  void _mergeSelectedTrips() {
    if (selectedTripIds.isEmpty) {
      return;
    }
    print("Merging the following trip IDs: $selectedTripIds");
    // TODO: Implement merging logic
    setState(() {
      isSelecting = false;
      selectedTripIds.clear();
    });
  }

  Future<void> _saveTripToFirestore(
    String title,
    DateTimeRange timeframe,
    List<Location> locations,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

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
