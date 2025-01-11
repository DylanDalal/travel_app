import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:photo_manager/photo_manager.dart' as photo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

class HomeScreen extends StatefulWidget {
  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  late MapboxMap mapboxMap;
  PointAnnotationManager? pointAnnotationManager;
  List<Location> photoLocations = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Home'),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.account_circle),
            onSelected: (value) {
              if (value == 'Profile') {
                Navigator.pushNamed(context, '/profile');
              } else if (value == 'Settings') {
                Navigator.pushNamed(context, '/settings');
              } else if (value == 'Logout') {
                _logout(context);
              }
            },
            itemBuilder: (BuildContext context) => [
              PopupMenuItem(value: 'Profile', child: Text('Profile')),
              PopupMenuItem(value: 'Settings', child: Text('Settings')),
              PopupMenuItem(value: 'Logout', child: Text('Logout')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: MapWidget(
              cameraOptions: CameraOptions(
                center: Point(coordinates: Position(0, 0)),
                zoom: 2.0,
              ),
              onMapCreated: _onMapCreated,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: fetchAndPlotPhotoMetadata,
              child: Text('Fetch and Plot Photo Metadata'),
            ),
          ),
        ],
      ),
    );
  }

  void _onMapCreated(MapboxMap mapboxMap) async {
    this.mapboxMap = mapboxMap;
    pointAnnotationManager =
        await mapboxMap.annotations.createPointAnnotationManager();
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
      type: photo.RequestType.image,
    );

    if (albums.isNotEmpty) {
      photo.AssetPathEntity recentAlbum = albums[0];
      List<photo.AssetEntity> photosz =
          await recentAlbum.getAssetListPaged(page: 0, size: 100);

      for (photo.AssetEntity photos in photosz) {
        if (photos.latitude != null && photos.longitude != null) {
          photoLocations.add(Location(
            latitude: photos.latitude!,
            longitude: photos.longitude!,
          ));
        }
      }

      _addMarkersToMap();
    } else {
      print('No albums found.');
    }
  }

  Future<void> _addMarkersToMap() async {
    if (pointAnnotationManager == null || photoLocations.isEmpty) {
      print("No annotation manager or photo locations available.");
      return;
    }

    // Load a custom marker image
    final ByteData bytes = await rootBundle.load('lib/assets/pin.png');
    final Uint8List imageData = bytes.buffer.asUint8List();

    for (var location in photoLocations) {
      pointAnnotationManager?.create(
        PointAnnotationOptions(
          geometry: Point(
            coordinates: Position(location.longitude, location.latitude),
          ),
          image: imageData,
          iconSize: .05,
        ),
      );
    }

    if (photoLocations.isNotEmpty) {
      mapboxMap.setCamera(
        CameraOptions(
          center: Point(
            coordinates: Position(
                photoLocations[0].longitude, photoLocations[0].latitude),
          ),
          zoom: 1.0,
        ),
      );
    }
  }

  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/');
  }
}

class Location {
  final double latitude;
  final double longitude;

  Location({required this.latitude, required this.longitude});
}
