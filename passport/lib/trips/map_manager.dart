import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart' show VoidCallback;
import 'dart:typed_data';
import 'dart:async';
import 'dart:math';

import '../classes.dart';

/// Simple class that manages Mapbox creation & annotation logic
class MapManager {
  late MapboxMap _mapboxMap;
  late PointAnnotationManager _pointAnnotationManager;
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  /// Callback for any post-plot logic
  final VoidCallback onPlotComplete;
  Timer? _rotationTimer;
  Timer? _interactionTimer;
  bool _userInteracted = false;
  double _rotationAngle = 0.0;
  CameraState? _lastCameraState;

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

      // Start rotating the globe
      _startRotatingGlobe();

      // Detect user interactions and stop rotation
      _mapboxMap.setOnMapMoveListener((point) => _handleUserInteraction());
      _mapboxMap.setOnMapTapListener((point) => _handleUserInteraction());

      print("Map interaction listeners added.");
    }).catchError((err) => print("Error creating manager: $err"));
  }

  void _startRotatingGlobe() async {
    _rotationTimer?.cancel(); // Cancel any previous timers
    _lastCameraState = await _mapboxMap.getCameraState();

    // Extract the initial camera position
    double initialLongitude =
        (_lastCameraState?.center?.coordinates.lng ?? 0.0).toDouble();
    double initialLatitude =
        (_lastCameraState?.center?.coordinates.lat ?? 0.0).toDouble();

    double rotationSpeed = 0.15; // Adjust rotation speed

    _rotationTimer = Timer.periodic(Duration(milliseconds: 100), (timer) async {
      if (_userInteracted) {
        timer.cancel();
        print("User interacted, stopping globe rotation.");
        return;
      }

      _lastCameraState = await _mapboxMap.getCameraState();
      double currentLongitude =
          _lastCameraState?.center?.coordinates.lng.toDouble() ??
              initialLongitude;
      double currentLatitude =
          _lastCameraState?.center?.coordinates.lat.toDouble() ??
              initialLatitude;

      double newLongitude = currentLongitude + rotationSpeed;
      if (newLongitude > 180) newLongitude -= 360; // Wrap around the globe

      _mapboxMap.setCamera(
        CameraOptions(
          center: Point(coordinates: Position(newLongitude, currentLatitude)),
          zoom: 1.5, // Keep zoom level fixed to view the whole globe
        ),
      );

    });

    print("Globe rotation started.");
  }

  /// Handles user interaction to stop the rotation and start resume timer
  void _handleUserInteraction() async {
    _userInteracted = true;
    _rotationTimer?.cancel();
    print("User interaction detected. Stopping rotation.");

    // Save current camera state
    var cameraState = await _mapboxMap.getCameraState();
    _lastCameraState = cameraState;

    _interactionTimer?.cancel();
    _interactionTimer = Timer(Duration(seconds: 5), () {
      print("Resuming globe rotation after inactivity.");
      _userInteracted = false;
      _startRotatingGlobe();
    });
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

      print("Pins plotted successfully.");

      onPlotComplete();
    } catch (e) {
      print("Error plotting locations: $e");
    }
  }
}
