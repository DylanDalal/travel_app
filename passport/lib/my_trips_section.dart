// lib/my_trips_section.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'classes.dart';
import 'home_screen.dart';
import 'dart:typed_data';
import 'package:flutter/services.dart'; // For rootBundle

// For the map:
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:photo_manager/photo_manager.dart' as photo;
import 'package:intl/intl.dart';

// Trip Edit Functionality
import 'trips/map_manager.dart';
import 'trips/trip_operations.dart';
import 'trips/create_trip_screen.dart';
import 'trips/edit_trip_screen.dart';
import 'trips/trip_detail_view.dart';
import 'trips/my_trip_list.dart';

class MyTripsSection extends StatefulWidget {
  @override
  _MyTripsSectionState createState() => _MyTripsSectionState();
}

class _MyTripsSectionState extends State<MyTripsSection> {
  // Screen flags
  bool isCreatingTrip = false;
  bool isEditingTrip = false;
  bool isViewingTrip = false;

  // Draggable sheet
  double currentChildSize = 0.25;

  // Data
  DateTimeRange? timeframe;
  final TextEditingController titleController = TextEditingController();
  List<Map<String, dynamic>> trips = [];
  List<Location> photoLocations = [];
  String? editingTripId;
  Map<String, dynamic>? selectedTrip;

  // Selection mode
  bool isSelecting = false;
  Set<String> selectedTripIds = {};

  // Map handling
  late MapManager mapManager;
  late MapboxMap mapboxMap;
  late PointAnnotationManager pointAnnotationManager;
  bool isPointAnnotationManagerInitialized = false;

  @override
  void initState() {
    super.initState();
    _loadTrips();
    // Set up the map manager
    mapManager = MapManager(onPlotComplete: () {
      print('Plot complete');
    });
  }

  // ---------------------
  // FIRESTORE / LOAD
  // ---------------------
  Future<void> _loadTrips() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final List<dynamic> tripData = userDoc.data()?['trips'] ?? [];
      setState(() {
        trips = tripData.map((t) => t as Map<String, dynamic>).toList();
      });
    } catch (e) {
      print('Error loading trips: $e');
    }
  }

  // ---------------------
  // MAP
  // ---------------------
  void _onMapCreated(MapboxMap map) {
    // Initialize our map manager (if using that approach)
    mapManager.initializeMapManager(map);

    // Also store references to map and annotation manager
    print('onMapCreated called');
    setState(() {
      mapboxMap = map;
    });

    // Create point annotation manager
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

  /// Actually plots photoLocations on the map
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

          pointAnnotationManager.create(
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

      print('Locations plotted successfully.');
    } catch (e) {
      print('Error plotting locations: $e');
    }
  }

  // Fetch photos in the timeframe, then plot them
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
      List<photo.AssetPathEntity> albums =
          await photo.PhotoManager.getAssetPathList(type: photo.RequestType.image);

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
        // Now that we have them, actually plot on the map
        _plotLocationsOnMap();
      }
    } catch (e) {
      print('Error fetching photo metadata: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching photo metadata.')),
      );
    }
  }

  // ---------------------
  // CREATE / EDIT
  // ---------------------
  Future<void> _createTrip(
    String tripTitle,
    DateTimeRange timeRange,
    List<Location> locations,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final updated = await TripOperations.createTrip(
        userUID: user.uid,
        currentTrips: trips,
        title: tripTitle,
        timeframe: timeRange,
        locations: locations,
      );
      setState(() {
        trips = updated;
        titleController.clear();
        timeframe = null;
        photoLocations.clear();
        isCreatingTrip = false;
        currentChildSize = 0.25;
      });
    } catch (e) {
      print("Error creating trip: $e");
    }
  }

  Future<void> _updateTrip(
    String tripTitle,
    DateTimeRange timeRange,
    List<Location> locations,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || editingTripId == null) return;

    try {
      final updated = await TripOperations.editTrip(
        userUID: user.uid,
        currentTrips: trips,
        editingTripId: editingTripId!,
        title: tripTitle,
        timeframe: timeRange,
        locations: locations,
      );
      setState(() {
        trips = updated;
        editingTripId = null;
        titleController.clear();
        timeframe = null;
        photoLocations.clear();
        isEditingTrip = false;
        currentChildSize = 0.25;
      });
    } catch (e) {
      print("Error updating trip: $e");
    }
  }

  // ---------------------
  // MERGE
  // ---------------------
  void _mergeSelectedTrips() {
    if (selectedTripIds.length < 2) {
      print("Need at least 2 trips to merge.");
      return;
    }

    // Example: might show a Cupertino dialog asking for merged name,
    // then call _performTripMerge( userTitle, deleteOldTrips )
    _performTripMerge("Merged Trip", false);
  }

  Future<void> _performTripMerge(String mergedTripName, bool deleteOldTrips) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final updated = await TripOperations.mergeTrips(
        userUID: user.uid,
        currentTrips: trips,
        selectedTripIds: selectedTripIds,
        mergedTripName: mergedTripName,
        deleteOldTrips: deleteOldTrips,
      );
      setState(() {
        trips = updated;
        selectedTripIds.clear();
        isSelecting = false;
      });
    } catch (e) {
      print("Error merging trips: $e");
    }
  }

  // ---------------------
  // SPLIT
  // ---------------------
  Future<void> _performTripSplit(DateTime splitDate) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || editingTripId == null) return;

    try {
      final updated = await TripOperations.splitTrip(
        userUID: user.uid,
        currentTrips: trips,
        editingTripId: editingTripId!,
        splitDate: splitDate,
      );
      setState(() {
        trips = updated;
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

  // ---------------------
  // DELETE
  // ---------------------
  Future<bool> _confirmSwipeDelete(Map<String, dynamic> trip) async {
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
              onPressed: () => Navigator.of(context).pop(true),
              child: Text("Delete", style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    ).then((value) {
      if (value == true) {
        _deleteTrip(trip['id']);
      }
      return value ?? false;
    });
  }

  Future<void> _deleteTrip(String tripId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final updatedTrips = trips.where((t) => t['id'] != tripId).toList();
      final userDoc = FirebaseFirestore.instance.collection('users').doc(user.uid);

      await userDoc.set({'trips': updatedTrips}, SetOptions(merge: true));
      setState(() {
        trips = updatedTrips;
        selectedTripIds.remove(tripId);
      });
    } catch (e) {
      print("Error deleting trip: $e");
    }
  }

  void _confirmDeleteSelected() {
    final count = selectedTripIds.length;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Confirm Delete"),
          content: Text(
              "Are you sure you want to delete $count selected ${count == 1 ? 'trip' : 'trips'}?"),
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
      final updatedTrips =
          trips.where((trip) => !toDelete.contains(trip['id'])).toList();
      final userDoc = FirebaseFirestore.instance.collection('users').doc(user.uid);

      await userDoc.set({'trips': updatedTrips}, SetOptions(merge: true));
      setState(() {
        trips = updatedTrips;
        selectedTripIds.clear();
        isSelecting = false;
      });
    } catch (e) {
      print("Error deleting multiple trips: $e");
    }
  }

  // ---------------------
  // UI BUILDER
  // ---------------------
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // The Map widget
        MapWidget(
          cameraOptions: CameraOptions(
            center: Point(coordinates: Position(0, 0)),
            zoom: 2.0,
          ),
          onMapCreated: _onMapCreated,
        ),
        // Draggable Sheet
        DraggableScrollableSheet(
          initialChildSize: currentChildSize,
          minChildSize: 0.25,
          maxChildSize: 0.5,
          builder: (context, scrollController) {
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
                    // The top row
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
    // If in selection mode, show "Merge / Deselect / Delete"
    if (isSelecting) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Merge (grayed out if < 2)
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

    // Otherwise, normal top row
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          _buildHeaderTitle(),
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        Row(
          children: [
            // "Select" if not editing, creating, or viewing
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

            // If editing or creating, show X; else show +
            if (isEditingTrip || isCreatingTrip)
              IconButton(
                icon: Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    if (isCreatingTrip) {
                      isCreatingTrip = false;
                      titleController.clear();
                      timeframe = null;
                      photoLocations.clear();
                      editingTripId = null;
                    }
                    if (isEditingTrip) {
                      isEditingTrip = false;
                      editingTripId = null;
                      titleController.clear();
                      timeframe = null;
                      photoLocations.clear();
                    }
                    currentChildSize = 0.25;
                  });
                },
              )
            else
              IconButton(
                icon: Icon(Icons.add),
                onPressed: () {
                  setState(() {
                    isCreatingTrip = true;
                    isEditingTrip = false;
                    isViewingTrip = false;
                    titleController.clear();
                    timeframe = null;
                    photoLocations.clear();
                    editingTripId = null;
                    currentChildSize = 0.5;
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
      // Show EditTripScreen
      return EditTripScreen(
        titleController: titleController,
        timeframe: timeframe,
        photoLocations: photoLocations,
        onPickDateRange: _pickDateRange,
        onFetchMetadata: fetchAndPlotPhotoMetadata,
        onUpdateTrip: _updateTrip,
        onSplitDate: _performTripSplit,
      );
    } else if (isCreatingTrip) {
      // Show CreateTripScreen
      return CreateTripScreen(
        titleController: titleController,
        timeframe: timeframe,
        photoLocations: photoLocations,
        onPickDateRange: _pickDateRange,
        onFetchMetadata: fetchAndPlotPhotoMetadata,
        onSaveTrip: _createTrip,
      );
    } else if (isViewingTrip && selectedTrip != null) {
      // Show Trip Details
      return TripDetailView(
        trip: selectedTrip!,
        onBack: () {
          setState(() {
            isViewingTrip = false;
            selectedTrip = null;
            currentChildSize = 0.25;
          });
        },
      );
    } else {
      // Show the main MyTripList
      return MyTripList(
        trips: trips,
        isSelecting: isSelecting,
        selectedTripIds: selectedTripIds,
        onConfirmSwipeDelete: _confirmSwipeDelete,
        onTapTrip: (trip) {
          setState(() {
            selectedTrip = trip;
            isViewingTrip = true;
            isEditingTrip = false;
            isCreatingTrip = false;
            currentChildSize = 0.5;
          });
        },
        onEditTrip: (trip) {
          final title = trip['title'] ?? '';
          final startIso = trip['timeframe']?['start'] ?? '';
          final endIso   = trip['timeframe']?['end']   ?? '';
          titleController.text = title;
          if (startIso.isNotEmpty && endIso.isNotEmpty) {
            final s = DateTime.parse(startIso);
            final e = DateTime.parse(endIso);
            timeframe = DateTimeRange(start: s, end: e);
          }
          editingTripId = trip['id'];
          setState(() {
            isEditingTrip = true;
            isCreatingTrip = false;
            isViewingTrip = false;
            currentChildSize = 0.5;
          });
        },
        onToggleSelection: (tripId, checked) {
          setState(() {
            if (checked) {
              selectedTripIds.add(tripId);
            } else {
              selectedTripIds.remove(tripId);
            }
          });
        },
      );
    }
  }

  // Let the user pick a date range in either create/edit
  Future<void> _pickDateRange() async {
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
  }
}
