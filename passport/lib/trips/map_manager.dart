// trips/map_manager.dart
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:typed_data';

import '../my_trips_section.dart'; 
// or wherever "Location" is defined, if needed (or re-define that class here).

/// Simple class that manages Mapbox creation & annotation logic
class MapManager {
  late MapboxMap _mapboxMap;
  late PointAnnotationManager _pointAnnotationManager;
  bool _isInitialized = false;

  /// Callback for any post-plot logic
  final VoidCallback onPlotComplete;

  MapManager({required this.onPlotComplete});

  /// Called once MapWidget is created
  void initializeMapManager(MapboxMap map) {
    _mapboxMap = map;
    _mapboxMap.annotations
        .createPointAnnotationManager()
        .then((manager) {
          _pointAnnotationManager = manager;
          _isInitialized = true;
        })
        .catchError((err) => print("Error creating manager: $err"));
  }

  /// Plot a list of photo locations
  Future<void> plotLocationsOnMap(List<Location> locations) async {
    if (!_isInitialized) {
      print("MapManager not initialized yet.");
      return;
    }

    try {
      _pointAnnotationManager.deleteAll();

      for (var loc in locations) {
        if (loc.latitude == 0 || loc.longitude == 0) continue;

        try {
          final ByteData bytes = await rootBundle.load('lib/assets/pin.png');
          final Uint8List imageData = bytes.buffer.asUint8List();

          await _pointAnnotationManager.create(
            PointAnnotationOptions(
              geometry: Point(
                coordinates: Position(loc.longitude, loc.latitude),
              ),
              image: imageData,
              iconSize: 0.05,
            ),
          );
        } catch (e) {
          print('Error creating marker: $e');
        }
      }

      if (locations.isNotEmpty) {
        // Center map on the first location
        final first = locations.first;
        _mapboxMap.setCamera(
          CameraOptions(
            center: Point(
              coordinates: Position(first.longitude, first.latitude),
            ),
            zoom: 1.0,
          ),
        );
      }

      onPlotComplete();
    } catch (e) {
      print("Error plotting locations: $e");
    }
  }
}
