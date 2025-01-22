// This file encapsulates logic for initializing the map, creating annotation managers, 
// and plotting points. Notice we call mapManager.initializeMapManager(map) from 
// _onMapCreated in my_trips_section.dart.
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart' show VoidCallback;
import 'dart:typed_data';

import '../classes.dart'; 

/// Simple class that manages Mapbox creation & annotation logic
class MapManager {

  late MapboxMap _mapboxMap;
  late PointAnnotationManager _pointAnnotationManager;
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;
  /// Callback for any post-plot logic
  final VoidCallback onPlotComplete;

  MapManager({required this.onPlotComplete});

  /// Called once MapWidget is created
void initializeMapManager(MapboxMap map) {
    if (_isInitialized) {
      print("MapManager is already initialized. Skipping re-initialization.");
      return;
    }

    _mapboxMap = map;
    _mapboxMap.annotations.createPointAnnotationManager().then((manager) {
      _pointAnnotationManager = manager;
      _isInitialized = true;
      print("MapManager initialized successfully.");
    }).catchError((err) => print("Error creating manager: $err"));
  }






  /// Plot a list of photo locations
 Future<void> plotLocationsOnMap(List<Location> locations) async {
    if (!isInitialized) {
      print("MapManager not initialized yet.");
      return;
    }

    try {
      print("Starting to plot ${locations.length} locations...");

      // Clear existing markers
      await _pointAnnotationManager.deleteAll();
      print("Deleted existing markers.");

      List<Location> validLocations = locations
          .where((loc) => loc.latitude != 0.0 && loc.longitude != 0.0)
          .toList();

      if (validLocations.isEmpty) {
        print("No valid locations to plot.");
        return;
      }

      for (var loc in validLocations) {
        try {
          final ByteData bytes = await rootBundle.load('lib/assets/pin.png');
          final Uint8List imageData = bytes.buffer.asUint8List();

          await _pointAnnotationManager.create(
            PointAnnotationOptions(
              geometry:
                  Point(coordinates: Position(loc.longitude, loc.latitude)),
              image: imageData,
              iconSize: 0.05,
            ),
          );

          print("Plotted pin at (${loc.latitude}, ${loc.longitude})");
        } catch (e) {
          print(
              'Error creating marker at (${loc.latitude}, ${loc.longitude}): $e');
        }
      }

      // Center the map on the first valid location
      final first = validLocations.first;
      _mapboxMap.setCamera(
        CameraOptions(
          center: Point(coordinates: Position(first.longitude, first.latitude)),
          zoom: 5.0, // Adjust zoom level
        ),
      );
      print("Map centered at (${first.latitude}, ${first.longitude})");

      onPlotComplete();
    } catch (e) {
      print("Error plotting locations: $e");
    }
  }

}
