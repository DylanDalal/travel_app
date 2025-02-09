// lib/user_data/data_operations.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle; // For loading JSON
import 'dart:convert'; // For jsonDecode
import 'dart:math' as math; // For haversineDistance
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:photo_manager/photo_manager.dart' as photo_manager;

import '../trips/map_manager.dart';
import '../classes.dart';
import '../utils/permission_utils.dart';

class DataFetcher {
  /// Fetch photo metadata stored in Firebase for a given timeframe
  static Future<List<Location>> fetchPhotoMetadataFromFirebase(
    String userId,
    DateTimeRange timeframe,
  ) async {
    final userDoc = FirebaseFirestore.instance.collection('users').doc(userId);
    final snapshot = await userDoc.get();

    if (!snapshot.exists) {
      throw Exception('No data found for the user in Firebase.');
    }

    // Retrieve photoLocations array from Firestore
    List<dynamic> photoData = snapshot.data()?['photoLocations'] ?? [];

    // Filter data based on the timeframe
    List<Location> filteredLocations = photoData
        .map((data) => Location(
              latitude: data['latitude'],
              longitude: data['longitude'],
              timestamp: data['timestamp'],
            ))
        .where((location) {
          final timestamp = DateTime.parse(location.timestamp);
          return timestamp.isAfter(timeframe.start) &&
              timestamp.isBefore(timeframe.end);
        })
        .toList();

    return filteredLocations;
  }
}

class DataSaver {
  /// Save photo metadata to Firebase
  static Future<void> savePhotoMetadataToFirebase(
    String userId,
    List<Location> photoLocations,
  ) async {
    final userDoc = FirebaseFirestore.instance.collection('users').doc(userId);

    // Prepare data for Firebase
    List<Map<String, dynamic>> locationData = photoLocations
        .map((location) => {
              'latitude': location.latitude,
              'longitude': location.longitude,
              'timestamp': location.timestamp,
            })
        .toList();

    print('Saving to Firebase: $locationData');

    // Store data in Firestore (merge so we don't overwrite other fields)
    await userDoc.set({
      'photoLocations': locationData,
    }, SetOptions(merge: true));
  }

  /// Sign up a user and initialize their data
  static Future<void> signUp({
    required String email,
    required String password,
    required BuildContext context,
  }) async {
    try {
      print("=============Signup initiated===============\n\n");

      // Create user with Firebase Authentication
      final userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      final userId = userCredential.user?.uid;
      if (userId == null) {
        throw Exception('Failed to retrieve user ID.');
      }

      // Initialize user document in Firestore
      await FirebaseFirestore.instance.collection('users').doc(userId).set({
        'email': email,
        'acceptedTerms': false, // Default value
      });

      // No photo permissions or metadata saving here.
      // We simply navigate the user to the next screen.
      Navigator.pushReplacementNamed(context, '/welcome');

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Signup failed: $e')),
      );
    }
  }
}

/*
    ===  Class CustomPhotoManager ===
    Responsible for locally retrieving photo metadata / dealing with permissions,
    city lookup, etc.
*/
class CustomPhotoManager {
  /// Master list of all known cities. Populated by loadAllCityDatasets().
  static List<City> allCities = [];

  /// Load city data from multiple JSON files (e.g., 7 continents + Central America).
  /// Once loaded, findClosestCity(...) can properly return city names.
  static Future<void> loadAllCityDatasets() async {
    const datasetFiles = [
      'lib/database/africa.json',
      'lib/database/asia.json',
      'lib/database/europe.json',
      'lib/database/north-america.json',
      'lib/database/south-america.json',
      'lib/database/oceania.json',
      'lib/database/antarctica.json',
      'lib/database/central-america.json',
    ];

    allCities.clear();

    for (final filePath in datasetFiles) {
      try {
        // Load the JSON from assets
        final dataString = await rootBundle.loadString(filePath);
        final List<dynamic> jsonList = jsonDecode(dataString);

        // Parse each city entry
        for (var item in jsonList) {
          final name = item['name'] as String?;
          final lat = item['latitude']?.toDouble();
          final lon = item['longitude']?.toDouble();

          // Skip invalid entries
          if (name == null || lat == null || lon == null) continue;

          allCities.add(City(name: name, latitude: lat, longitude: lon));
        }
      } catch (e) {
        print('Error loading $filePath: $e');
      }
    }

    print('Loaded ${allCities.length} total cities from datasets.');
  }

  /// Return the city in [allCities] closest to (lat, lon).
  /// If [allCities] is empty or none found, returns null.
  static City? findClosestCity(double lat, double lon) {
    if (allCities.isEmpty) {
      // If user hasn't called loadAllCityDatasets(), city remains unknown
      return null;
    }

    City? closestCity;
    double minDistance = double.infinity;

    for (final city in allCities) {
      final distance = _haversineDistance(lat, lon, city.latitude, city.longitude);
      if (distance < minDistance) {
        minDistance = distance;
        closestCity = city;
      }
    }
    return closestCity;
  }

  /// Calculate approximate distance in km between two lat/lon points.
  static double _haversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371; // Earth's radius in km
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }

  static double _toRadians(double deg) => deg * (math.pi / 180.0);

  /// Fetch all photo metadata from the device
  static Future<List<Location>> fetchAllPhotoMetadata() async {
    List<Location> locations = [];
    try {
      // Request permission
      final photo_manager.PermissionState permission =
          await photo_manager.PhotoManager.requestPermissionExtend();

      if (!permission.isAuth) {
        print('Photo access denied.');
        return locations;
      }

      // Fetch all albums
      final List<photo_manager.AssetPathEntity> albums =
          await photo_manager.PhotoManager.getAssetPathList(
        type: photo_manager.RequestType.image,
        hasAll: true,
      );

      for (final photo_manager.AssetPathEntity album in albums) {
        final List<photo_manager.AssetEntity> photos =
            await album.getAssetListPaged(page: 0, size: 10000);

        for (final photo_manager.AssetEntity asset in photos) {
          if (asset.latitude != null && asset.longitude != null) {
            final double latitude = asset.latitude!;
            final double longitude = asset.longitude!;
            final DateTime date = asset.createDateTime;

            final Location location = Location(
              latitude: latitude,
              longitude: longitude,
              timestamp: date.toIso8601String(),
            );
            locations.add(location);
          }
        }
      }
    } catch (e) {
      print('Error fetching photo metadata: $e');
    }
    return locations;
  }

  /// Fetch and plot photo metadata on the map (device-level fetching).
  /// Called ONLY if user opts to "Automatically Load Trips."
  static Future<void> fetchAndPlotPhotoMetadata(
    BuildContext context,
    MapManager mapManager,
    DateTimeRange timeframe,
  ) async {
    if (timeframe == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a timeframe first.')),
      );
      return;
    }
    
    final photo_manager.PermissionState state =
        await photo_manager.PhotoManager.requestPermissionExtend();
    print('Photo permission state: $state');

    if (!state.isAuth) {
      print('Photo access denied.');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photo access is required to fetch photos.')),
      );
      return;
    }

    try {
      await loadAllCityDatasets();

      final List<photo_manager.AssetPathEntity> albums =
          await photo_manager.PhotoManager.getAssetPathList(
        type: photo_manager.RequestType.image,
      );

      if (albums.isEmpty) {
        print('No photo albums found.');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No photo albums found.')),
        );
        return;
      }

      photo_manager.AssetPathEntity recentAlbum = albums[0];
      final List<photo_manager.AssetEntity> userPhotos =
          await recentAlbum.getAssetListPaged(page: 0, size: 100);

      if (userPhotos.isEmpty) {
        print('No photos found in the album.');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No photos found in the album.')),
        );
        return;
      }

      List<Location> photoLocations = [];
      final start = timeframe.start;
      final end = timeframe.end;

      for (final photo_manager.AssetEntity photoEntity in userPhotos) {
        final lat = photoEntity.latitude ?? 0.0;
        final lon = photoEntity.longitude ?? 0.0;
        final createTime = photoEntity.createDateTime;

        if (lat != 0.0 &&
            lon != 0.0 &&
            createTime.isAfter(start) &&
            createTime.isBefore(end)) {

          // 1) Find the city
          final city = findClosestCity(lat, lon);
          final cityName = city?.name ?? 'Unknown';

          // 2) Print with city name
          print("Fetched photo: $lat, $lon  Closest City: $cityName");

          // 3) Build the location object
          photoLocations.add(
            Location(
              latitude: lat,
              longitude: lon,
              timestamp: createTime.toIso8601String(),
            ),
          );
        } else {
          print("Skipping invalid/out-of-range photo: $lat, $lon");
        }
      }

      if (photoLocations.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No photos found in the selected timeframe.')),
        );
        return;
      }

      print("Plotting ${photoLocations.length} locations on the map.");
      await mapManager.plotLocationsOnMap(photoLocations);
      print("Markers plotted on map");

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({
          'photoLocations': photoLocations.map((loc) => loc.toMap()).toList(),
        }, SetOptions(merge: true));

        print("Photo data saved to 'users/{uid}/photoLocations'.");
      } else {
        print("No authenticated user found. Cannot save to Firebase.");
      }
    } catch (e) {
      print('Error fetching photo metadata: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error fetching photo metadata.')),
      );
    }
  }

  /// Open app settings to grant photo access
  static Future<void> openSettingsIfNeeded(BuildContext context) async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Photo Access Required'),
        content: const Text('To continue using the app, please grant photo access.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              photo_manager.PhotoManager.openSetting();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }
}
