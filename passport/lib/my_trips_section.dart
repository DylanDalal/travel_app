// lib/my_trips_section.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// For the map:
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:photo_manager/photo_manager.dart' as photo;

// Our new modules (adjust paths as needed)
import 'trips/map_manager.dart';
import 'trips/trip_operations.dart';
import 'trips/create_trip_screen.dart';
import 'trips/edit_trip_screen.dart';
import 'trips/trip_detail_view.dart';
import 'trips/my_trip_list.dart';
import 'classes.dart'; // For the Location class, etc.
import 'package:passport/user_data/data_operations.dart'; // For the new fetch/plot methods
import 'dart:async';
import 'package:intl/intl.dart';

class MyTripsSection extends StatefulWidget {
  final MapManager mapManager;
  final VoidCallback? onMapInitialized;

  MyTripsSection({
    Key? key,
    required this.mapManager,
    this.onMapInitialized,
  }) : super(key: key);

  @override
  _MyTripsSectionState createState() => _MyTripsSectionState();
}

class _MyTripsSectionState extends State<MyTripsSection> {
  bool isCreatingTrip = false;
  bool isEditingTrip = false;
  bool isViewingTrip = false;

  double currentChildSize = 0.25;
  DateTimeRange? timeframe;
  final TextEditingController titleController = TextEditingController();
  List<Map<String, dynamic>> trips = [];
  String? editingTripId;
  Map<String, dynamic>? selectedTrip;

  bool isSelecting = false;
  Set<String> selectedTripIds = {};

  late MapManager mapManager;
  bool isMapInitialized = false;
  final Key _mapKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    mapManager = widget.mapManager;
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
        trips = tripData.map((t) => t as Map<String, dynamic>).toList();
      });
    } catch (e) {
      print('Error loading trips: $e');
    }
  }

  void _onMapCreated(MapboxMap map) {
    widget.mapManager.initializeMapManager(map);
    _checkMapInitialization();
  }

  void _checkMapInitialization() {
    const Duration checkInterval = Duration(milliseconds: 100);
    Timer.periodic(checkInterval, (timer) {
      if (widget.mapManager.isInitialized) {
        setState(() {
          isMapInitialized = true;
          print("MapManager is initialized: $isMapInitialized");
        });
        timer.cancel();

        // Once map is ready, invoke the callback if provided
        widget.onMapInitialized?.call();
      }
    });
  }

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
        isEditingTrip = false;
        currentChildSize = 0.25;
      });
    } catch (e) {
      print("Error updating trip: $e");
    }
  }

  void _mergeSelectedTrips() {
    if (selectedTripIds.length < 2) {
      print("Need at least 2 trips to merge.");
      return;
    }
    _performTripMerge("Merged Trip", false);
  }

  Future<void> _performTripMerge(
      String mergedTripName, bool deleteOldTrips) async {
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

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        MapWidget(
          key: _mapKey,
          cameraOptions: CameraOptions(
            center: Point(coordinates: Position(0, 0)),
            zoom: 2.0,
          ),
          onMapCreated: _onMapCreated,
        ),

        if (!isMapInitialized)
          const Center(child: CircularProgressIndicator()),

        AbsorbPointer(
          absorbing: !isMapInitialized,
          child: DraggableScrollableSheet(
            initialChildSize: currentChildSize,
            minChildSize: 0.25,
            maxChildSize: 0.5,
            builder: (context, scrollController) {
              return GestureDetector(
                onTap: () {
                  setState(() {
                    currentChildSize =
                        (currentChildSize == 0.25) ? 0.5 : 0.25;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(20)),
                    boxShadow: const [
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
        ),
      ],
    );
  }

  Widget _buildTopRow() {
    if (isSelecting) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton(
            onPressed: selectedTripIds.length > 1 ? _mergeSelectedTrips : null,
            child: Text(
              "Merge",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: (selectedTripIds.length > 1) ? Colors.blue : Colors.grey,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                isSelecting = false;
                selectedTripIds.clear();
              });
            },
            child: Text("Deselect",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
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
            if (isEditingTrip || isCreatingTrip || isViewingTrip)
              IconButton(
                icon: Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    if (isCreatingTrip) {
                      isCreatingTrip = false;
                      titleController.clear();
                      timeframe = null;
                      editingTripId = null;
                    }
                    if (isEditingTrip) {
                      isEditingTrip = false;
                      editingTripId = null;
                      titleController.clear();
                      timeframe = null;
                    }
                    if (isViewingTrip) {
                      isViewingTrip = false;
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
      return EditTripScreen(
        titleController: titleController,
        timeframe: timeframe,
        photoLocations: [],
        onPickDateRange: _pickDateRange,
        onFetchMetadata: () async {
          if (!isMapInitialized) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Map is not ready yet.')),
            );
            return;
          }
          if (timeframe == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Please pick a date range first.')),
            );
            return;
          }
          // Call the new fetchPhotoMetadata 
          await CustomPhotoManager.fetchPhotoMetadata(
            context: context,
            timeframe: timeframe!,
          );
          // Then refresh local trips
          await _loadTrips();
        },
        onUpdateTrip: _updateTrip,
        onSplitDate: _performTripSplit,
      );
    } else if (isCreatingTrip) {
      return CreateTripScreen(
        titleController: titleController,
        timeframe: timeframe,
        photoLocations: [],
        onPickDateRange: _pickDateRange,
        onFetchMetadata: () async {
          if (!isMapInitialized) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Map is not ready yet.')),
            );
            return;
          }
          if (timeframe == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Please pick a date range first.')),
            );
            return;
          }
          // fetch from device, store in firebase
          await CustomPhotoManager.fetchPhotoMetadata(
            context: context,
            timeframe: timeframe!,
          );
          // reload the local trips to see new data
          await _loadTrips();
        },
        onSaveTrip: _createTrip,
      );
    } else if (isViewingTrip && selectedTrip != null) {
      return TripDetailView(
        trip: selectedTrip!,
        onBack: () {
          setState(() {
            isViewingTrip = false;
            selectedTrip = null;
            currentChildSize = 0.25;
          });
          widget.mapManager.zoomBackOut();
          widget.mapManager.setViewingTrip(false);
        },
      );
    } else {
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
          widget.mapManager.setViewingTrip(false);
          if (trip['locations'] != null && trip['locations'].isNotEmpty) {
            final firstLocation = trip['locations'][0];
            widget.mapManager.flyToLocation(
              firstLocation['latitude'],
              firstLocation['longitude'],
            );
          }
        },
        onEditTrip: (trip) {
          final title = trip['title'] ?? '';
          final startIso = trip['timeframe']?['start'] ?? '';
          final endIso = trip['timeframe']?['end'] ?? '';
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

  Widget _buildTripDateRange(Map<String, dynamic> trip) {
    final timeframe = trip['timeframe'];
    if (timeframe == null) return const Text('');
    
    final startDate = DateTime.parse(timeframe['start']);
    final endDate = DateTime.parse(timeframe['end']);
    
    // If start and end dates are the same, show single date
    if (startDate.year == endDate.year && 
        startDate.month == endDate.month && 
        startDate.day == endDate.day) {
      return Text(
        DateFormat('MMM d, yyyy').format(startDate),
        style: TextStyle(color: Colors.grey[600], fontSize: 14),
      );
    }
    
    // Otherwise show date range
    return Text(
      '${DateFormat('MMM d').format(startDate)} - ${DateFormat('MMM d, yyyy').format(endDate)}',
      style: TextStyle(color: Colors.grey[600], fontSize: 14),
    );
  }
}