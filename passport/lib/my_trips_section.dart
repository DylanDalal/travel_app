import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:photo_manager/photo_manager.dart' as photo;
import 'package:firebase_auth/firebase_auth.dart';

class MyTripsSection extends StatefulWidget {
  @override
  _MyTripsSectionState createState() => _MyTripsSectionState();
}

class _MyTripsSectionState extends State<MyTripsSection> {
  late MapboxMap mapboxMap;
  List<Map<String, dynamic>> trips = [];
  bool isAddingNewTrip = false;

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

      for (photo.AssetEntity photo_entity in userPhotos) {
        if (photo_entity.latitude != null && photo_entity.longitude != null) {
          photoMetadata.add({
            "latitude": photo_entity.latitude,
            "longitude": photo_entity.longitude,
            "timestamp": photo_entity.createDateTime.toIso8601String(),
            "fileName": photo_entity.title ?? "Unknown",
          });
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
          initialChildSize: isAddingNewTrip ? 0.5 : 0.25,
          minChildSize: 0.25,
          maxChildSize: 0.75,
          builder: (BuildContext context, ScrollController scrollController) {
            return Container(
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
                          icon: Icon(isAddingNewTrip ? Icons.close : Icons.add),
                          onPressed: () {
                            setState(() {
                              isAddingNewTrip = !isAddingNewTrip;
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
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton(
            onPressed: fetchAndPlotPhotoMetadata,
            child: Text('Fetch and Plot Photo Metadata'),
          ),
          SizedBox(height: 10),
          ElevatedButton(
            onPressed: () {
              // Add other trip creation logic here
              print('Other trip creation logic');
            },
            child: Text('Other Trip Settings'),
          ),
        ],
      ),
    );
  }
}
