import 'classes.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:photo_manager/photo_manager.dart' as photo;
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class MyTripsSection extends StatefulWidget {
  @override
  _MyTripsSectionState createState() => _MyTripsSectionState();
}

class _MyTripsSectionState extends State<MyTripsSection> {
  /// Which UI screen we’re showing
  bool isCreatingTrip = false;
  bool isEditingTrip = false;
  bool isViewingTrip = false;

  double currentChildSize = 0.25;
  DateTimeRange? timeframe;

  // For trip creation/editing
  final TextEditingController titleController = TextEditingController();

  // The map
  late MapboxMap mapboxMap;
  late PointAnnotationManager pointAnnotationManager;
  bool isPointAnnotationManagerInitialized = false;

  // Data
  List<Map<String, dynamic>> trips = [];
  List<Location> photoLocations = [];
  String? editingTripId; // which trip ID we’re editing
  Map<String, dynamic>? selectedTrip; // which trip is being viewed

  // Selection mode
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
      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final List<dynamic> tripData = userDoc.data()?['trips'] ?? [];

      setState(() {
        trips = tripData.map((trip) => trip as Map<String, dynamic>).toList();
      });
    } catch (e) {
      print('Error loading trips: $e');
    }
  }

  /// Format "Oct. 08th, 2024" from an ISO datetime string
  String _formatDateString(String isoString) {
    try {
      DateTime dateObj = DateTime.parse(isoString);
      return _formatDate(dateObj);
    } catch (_) {
      return isoString;
    }
  }

  /// Abbreviated month, e.g. "Oct. 08th, 2024"
  String _formatDate(DateTime date) {
    final day = date.day;
    final dayString = day < 10 ? '0$day' : '$day';
    final suffix = _daySuffix(day);
    final month = DateFormat('MMM').format(date) + '.';
    final year = date.year;
    return '$month $dayString$suffix, $year';
  }

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
      List<photo.AssetPathEntity> albums = await photo.PhotoManager.getAssetPathList(
        type: photo.RequestType.image,
      );

      if (albums.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No photo albums found.')),
        );
        return;
      }

      photo.AssetPathEntity recentAlbum = albums[0];
      List<photo.AssetEntity> userPhotos =
          await recentAlbum.getAssetListPaged(page: 0, size: 100);

      if (userPhotos.isEmpty) {
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

    map.annotations.createPointAnnotationManager().then((manager) {
      setState(() {
        pointAnnotationManager = manager;
        isPointAnnotationManagerInitialized = true;
        _plotLocationsOnMap();
      });
    }).catchError((error) {
      print('Error initializing PointAnnotationManager: $error');
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
          onMapCreated: _onMapCreated,
        ),
        // The Draggable sheet on top
        DraggableScrollableSheet(
          initialChildSize: currentChildSize,
          minChildSize: 0.25,
          maxChildSize: 0.5,
          builder: (BuildContext context, ScrollController scrollController) {
            return GestureDetector(
              onTap: () {
                setState(() {
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

  Widget _buildTopRow() {
    if (isSelecting) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Merge (disabled if <2 selected)
          TextButton(
            onPressed: (selectedTripIds.length > 1) ? _mergeSelectedTrips : null,
            child: Text(
              "Merge",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: (selectedTripIds.length > 1) ? Colors.blue : Colors.grey,
              ),
            ),
          ),
          // Deselect
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
          // Delete
          TextButton(
            onPressed: selectedTripIds.isNotEmpty ? _confirmDeleteSelected : null,
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

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          _buildHeaderTitle(),
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        Row(
          children: [
            // "Select" if not editing/viewing/creating
            if (!isEditingTrip && !isCreatingTrip && !isViewingTrip)
              TextButton(
                onPressed: () {
                  setState(() {
                    isSelecting = true;
                    selectedTripIds.clear();
                  });
                },
                child: Text("Select"),
              ),
            // plus or close
            IconButton(
              icon: Icon(isCreatingTrip ? Icons.close : Icons.add),
              onPressed: () {
                setState(() {
                  if (isCreatingTrip) {
                    // if we are on "create trip" screen, close it
                    titleController.clear();
                    timeframe = null;
                    photoLocations.clear();
                    editingTripId = null;
                    isCreatingTrip = false;
                  } else {
                    // open create trip screen
                    isCreatingTrip = true;
                    isEditingTrip = false;
                    isViewingTrip = false;
                    titleController.clear();
                    timeframe = null;
                    photoLocations.clear();
                    editingTripId = null;
                  }
                  currentChildSize = isCreatingTrip ? 0.5 : 0.25;
                });
              },
            ),
          ],
        ),
      ],
    );
  }

  String _buildHeaderTitle() {
    if (isEditingTrip) return 'Edit Trip';
    if (isCreatingTrip) return 'Create Trip';
    if (isViewingTrip) return 'Trip Details';
    return 'My Trips';
  }

  Widget _buildChildContent(ScrollController scrollController) {
    if (isEditingTrip) {
      return _buildEditTripScreen(scrollController);
    } else if (isCreatingTrip) {
      return _buildCreateTripScreen(scrollController);
    } else if (isViewingTrip && selectedTrip != null) {
      return _buildTripDetailView(scrollController);
    } else {
      return _buildTripList(scrollController);
    }
  }

  // -------------------------
  // CREATE TRIP SCREEN
  // -------------------------
  Widget _buildCreateTripScreen(ScrollController scrollController) {
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
                // Standard Material date range
                final pickedRange = await showDateRangePicker(
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
                  titleController.clear();
                  timeframe = null;
                  photoLocations.clear();
                  isCreatingTrip = false;
                  currentChildSize = 0.25;
                });
              },
              child: Text('Save Trip'),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------
  // EDIT TRIP SCREEN
  // -------------------------
  Widget _buildEditTripScreen(ScrollController scrollController) {
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
                final pickedRange = await showDateRangePicker(
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

                // Save updates
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
                  editingTripId = null;
                  isEditingTrip = false;
                  currentChildSize = 0.25;
                });
              },
              child: Text('Update Trip'),
            ),
            SizedBox(height: 10),
            // SPLIT TRIP BUTTON
            ElevatedButton(
              onPressed: () async {
                // Pick a single date somewhere in [timeframe].
                final splitted = await _promptSplitDate();
                if (splitted != null) {
                  await _performTripSplit(splitted);
                }
              },
              child: Text('Split Trip'),
            ),
          ],
        ),
      ),
    );
  }

  /// The user picks a single date for splitting. We'll show a normal Material date picker.
  Future<DateTime?> _promptSplitDate() async {
    final DateTime today = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: today,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    return picked;
  }

  /// Actually split the current trip at [splitDate] if editingTripId is not null.
  /// All data after [splitDate] goes into a new trip named "x 2" (where x = original name).
  Future<void> _performTripSplit(DateTime splitDate) async {
    if (editingTripId == null) {
      print("No trip to split (editingTripId is null).");
      return;
    }

    // Find the original trip in local array
    final originalIndex = trips.indexWhere((t) => t['id'] == editingTripId);
    if (originalIndex < 0) {
      print("Trip not found locally with ID $editingTripId");
      return;
    }

    final originalTrip = trips[originalIndex];
    final String originalTitle = originalTrip['title'] ?? 'Untitled Trip';
    final Map<String, dynamic>? originalTimeframe = originalTrip['timeframe'];
    if (originalTimeframe == null) {
      print("No timeframe in original trip. Cannot split.");
      return;
    }

    // Convert timeframe to DateTimes
    final startIso = originalTimeframe['start'];
    final endIso   = originalTimeframe['end'];
    if (startIso == null || endIso == null) {
      print("Original trip timeframe is missing data. Cannot split.");
      return;
    }
    final startDate = DateTime.parse(startIso);
    final endDate   = DateTime.parse(endIso);

    // Ensure splitDate is between start & end
    if (splitDate.isBefore(startDate) || splitDate.isAfter(endDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Split date is outside the trip timeframe!')),
      );
      return;
    }

    // Build the second trip's timeframe from splitDate -> original end
    final newTimeframe = {
      'start': splitDate.toIso8601String(),
      'end': endDate.toIso8601String(),
    };

    // The original trip timeframe becomes [startDate, splitDate)
    final updatedOriginalTimeframe = {
      'start': startDate.toIso8601String(),
      'end': splitDate.toIso8601String(),
    };

    // Split the data
    // If 'locations' exists, move all that are AFTER splitDate into the new trip
    final originalLocations = (originalTrip['locations'] ?? []) as List<dynamic>;
    final List<dynamic> newLocations = [];

    // Partition the existing locations
    final updatedOriginalLocations = <dynamic>[];
    for (var loc in originalLocations) {
      if (loc is Map<String, dynamic>) {
        final tsStr = loc['timestamp'] as String?;
        if (tsStr != null) {
          final locDate = DateTime.parse(tsStr);
          // If after the split, it goes to new trip
          if (locDate.isAfter(splitDate)) {
            newLocations.add(loc);
            continue;
          }
        }
      }
      updatedOriginalLocations.add(loc);
    }

    // Build the second trip
    final newTrip = Map<String, dynamic>.from(originalTrip); 
    newTrip['id'] = UniqueKey().toString();
    newTrip['title'] = originalTitle + " 2";
    newTrip['timeframe'] = newTimeframe;
    newTrip['locations'] = newLocations;

    // Update the original trip
    final updatedOriginalTrip = Map<String, dynamic>.from(originalTrip);
    updatedOriginalTrip['timeframe'] = updatedOriginalTimeframe;
    updatedOriginalTrip['locations'] = updatedOriginalLocations;

    // Update our local array
    final updatedTrips = List<Map<String, dynamic>>.from(trips);
    updatedTrips[originalIndex] = updatedOriginalTrip; 
    updatedTrips.add(newTrip);

    // Write to Firestore
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final userDoc = FirebaseFirestore.instance.collection('users').doc(user.uid);
      await userDoc.set({'trips': updatedTrips}, SetOptions(merge: true));
      setState(() {
        trips = updatedTrips;
        // After splitting, we can close the Edit screen, etc.
        editingTripId = null;
        isEditingTrip = false;
        currentChildSize = 0.25;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Trip split successfully!')),
        );
      });
    } catch (e) {
      print("Error splitting trip: $e");
    }
  }

  // -------------------------
  // TRIP DETAILS
  // -------------------------
  Widget _buildTripDetailView(ScrollController scrollController) {
    if (selectedTrip == null) {
      return Center(child: Text("No trip selected"));
    }

    final trip = selectedTrip!;
    final String title = trip['title'] ?? 'Untitled Trip';

    final String rawStart = trip['timeframe']?['start'] ?? '';
    final String rawEnd = trip['timeframe']?['end'] ?? '';
    final String formattedStart =
        rawStart.isEmpty ? 'Unknown' : _formatDateString(rawStart);
    final String formattedEnd =
        rawEnd.isEmpty ? 'Unknown' : _formatDateString(rawEnd);

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

  // -------------------------
  // MY TRIPS LIST
  // -------------------------
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
                subtitle: Text(displayDate),
                onTap: () {
                  // If in selection mode, toggle
                  if (isSelecting) {
                    setState(() {
                      if (isSelected) {
                        selectedTripIds.remove(tripId);
                      } else {
                        selectedTripIds.add(tripId);
                      }
                    });
                  } else {
                    // View details
                    setState(() {
                      selectedTrip = trip;
                      isViewingTrip = true;
                      isEditingTrip = false;
                      isCreatingTrip = false;
                      currentChildSize = 0.5;
                    });
                  }
                },
                trailing: IconButton(
                  icon: Icon(Icons.edit),
                  onPressed: () {
                    // Switch to Edit Trip screen
                    setState(() {
                      // Pre-fill the fields
                      titleController.text = trip['title'] ?? '';
                      if (startIso.isNotEmpty && endIso.isNotEmpty) {
                        final start = DateTime.parse(startIso);
                        final end = DateTime.parse(endIso);
                        timeframe = DateTimeRange(start: start, end: end);
                      }
                      editingTripId = tripId;

                      isEditingTrip = true;
                      isCreatingTrip = false;
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

  // -------------------------
  // SWIPE TO DELETE
  // -------------------------
  Future<bool> _confirmSwipeDelete(Map<String, dynamic> trip) async {
    final tripId = trip['id'];
    final tripTitle = trip['title'] ?? 'Untitled Trip';

    return await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Confirm Delete"),
          content: Text("Are you sure you want to delete the trip '$tripTitle'?"),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
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
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
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

  // -------------------------
  // MERGE TRIPS (Cupertino style)
  // -------------------------
  void _mergeSelectedTrips() {
    if (selectedTripIds.length < 2) {
      print("Need at least 2 trips to merge.");
      return;
    }

    // Find the earliest trip among selected to get default name
    final selectedList = trips.where((t) => selectedTripIds.contains(t['id'])).toList();
    Map<String, dynamic>? earliestTrip;
    DateTime? earliestDate;

    for (var trip in selectedList) {
      final startStr = trip['timeframe']?['start'];
      if (startStr != null) {
        final startDate = DateTime.parse(startStr);
        if (earliestDate == null || startDate.isBefore(earliestDate)) {
          earliestDate = startDate;
          earliestTrip = trip;
        }
      }
    }

    final defaultName = earliestTrip?['title'] ?? 'Merged Trip';
    final TextEditingController mergeNameController =
        TextEditingController(text: defaultName);

    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title: Text("Merge Trips", textAlign: TextAlign.center),
          content: Column(
            children: [
              SizedBox(height: 12),
              CupertinoTextField(
                controller: mergeNameController,
                placeholder: "New Trip Name",
              ),
            ],
          ),
          actions: [
            CupertinoDialogAction(
              child: Text("Cancel", textAlign: TextAlign.center),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            CupertinoDialogAction(
              child: Text("Merge & Keep Old Trips", textAlign: TextAlign.center),
              onPressed: () async {
                Navigator.of(context).pop();
                await _performTripMerge(
                  mergeNameController.text,
                  deleteOldTrips: false,
                );
              },
            ),
            CupertinoDialogAction(
              child: Text("Merge & Delete Old Trips", textAlign: TextAlign.center),
              onPressed: () async {
                Navigator.of(context).pop();
                await _performTripMerge(
                  mergeNameController.text,
                  deleteOldTrips: true,
                );
              },
            ),
          ],
        );
      },
    );
  }

  /// Actually merges the selected trips into a new one
  Future<void> _performTripMerge(String mergedTripName,
      {required bool deleteOldTrips}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('No authenticated user, cannot merge.');
      return;
    }

    final selected = trips.where((trip) => selectedTripIds.contains(trip['id'])).toList();
    if (selected.isEmpty) {
      print("No trips to merge.");
      return;
    }

    // earliest / latest
    DateTime? earliest;
    DateTime? latest;
    for (var trip in selected) {
      final startStr = trip['timeframe']?['start'];
      final endStr = trip['timeframe']?['end'];
      if (startStr != null && endStr != null) {
        final startDate = DateTime.parse(startStr);
        final endDate = DateTime.parse(endStr);
        if (earliest == null || startDate.isBefore(earliest)) {
          earliest = startDate;
        }
        if (latest == null || endDate.isAfter(latest)) {
          latest = endDate;
        }
      }
    }

    // Merge data from all selected
    Map<String, dynamic> mergedData = {};
    for (var trip in selected) {
      trip.forEach((key, value) {
        if (key == 'id' || key == 'timeframe' || key == 'title') {
          return;
        }
        if (!mergedData.containsKey(key)) {
          mergedData[key] = value;
        } else {
          if (mergedData[key] is List && value is List) {
            mergedData[key].addAll(value);
          } else {
            mergedData[key] = value;
          }
        }
      });
    }

    final mergedTimeframe = {
      "start": earliest?.toIso8601String() ?? DateTime.now().toIso8601String(),
      "end": latest?.toIso8601String() ?? DateTime.now().toIso8601String(),
    };

    // Construct the new trip object
    final newTrip = {
      // Put merged data first
      ...mergedData,
      "id": UniqueKey().toString(),
      "timeframe": mergedTimeframe,
      // *Finally*, override the title with user input
      "title": mergedTripName,
    };

    try {
      final userDoc = FirebaseFirestore.instance.collection('users').doc(user.uid);

      List<Map<String, dynamic>> updatedTrips;
      if (deleteOldTrips) {
        updatedTrips = trips.where((t) => !selectedTripIds.contains(t['id'])).toList();
      } else {
        updatedTrips = List.from(trips);
      }
      updatedTrips.add(newTrip);

      await userDoc.set({'trips': updatedTrips}, SetOptions(merge: true));
      setState(() {
        trips = updatedTrips;
        selectedTripIds.clear();
        isSelecting = false;
      });
      print("Trip merge successful. Created trip '$mergedTripName'");
    } catch (e) {
      print("Error merging trips: $e");
    }
  }

  // -------------------------
  // CREATE / EDIT Trip in Firestore
  // -------------------------
  Future<void> _saveTripToFirestore(
    String title,
    DateTimeRange timeframe,
    List<Location> locations,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final userDoc = FirebaseFirestore.instance.collection('users').doc(user.uid);

      // If editing an existing trip
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
        // Creating new trip
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
