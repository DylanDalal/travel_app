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
      // 1) Load all cities
      await loadAllCityDatasets();

      // 2) Print user hometowns
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print("No authenticated user found. Cannot fetch hometowns.");
        return;
      }

      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final hometowns = userDoc.data()?['hometowns'] as List<dynamic>? ?? [];
      print("User's hometowns: $hometowns");

      // 3) Get all albums & photos
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

      // For simplicity, pick the first album
      final photo_manager.AssetPathEntity recentAlbum = albums[0];
      final List<photo_manager.AssetEntity> userPhotos =
          await recentAlbum.getAssetListPaged(page: 0, size: 100);

      if (userPhotos.isEmpty) {
        print('No photos found in the album.');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No photos found in the album.')),
        );
        return;
      }

      // 4) Filter userPhotos by timeframe, gather into [photoLocations]
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
          // Find city
          final city = findClosestCity(lat, lon);
          final cityName = city?.name ?? 'Unknown';

          print("Fetched photo: $lat, $lon  Closest City: $cityName");

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

      print("Processing ${photoLocations.length} locations.");
      mapManager.plotLocationsOnMap(photoLocations);

      // 5) Build "trips" from [photoLocations], grouped by 7-day gaps
      photoLocations.sort((a, b) =>
          DateTime.parse(a.timestamp).compareTo(DateTime.parse(b.timestamp)));

      final List<Map<String, dynamic>> trips = [];
      Map<String, dynamic>? currentTrip;
      final int dayGap = 7;
      DateTime? lastPhotoTime;

      for (int i = 0; i < photoLocations.length; i++) {
        final loc = photoLocations[i];
        final thisPhotoTime = DateTime.parse(loc.timestamp);

        if (currentTrip == null) {
          // Create first trip
          final city = findClosestCity(loc.latitude, loc.longitude);
          final cityName = city?.name ?? 'Unknown';

          currentTrip = {
            'id': _generateTripId(), // e.g. "#a1b2c"
            'title': cityName,
            'timeframe': {
              'start': loc.timestamp,
              'end': loc.timestamp,
            },
            'locations': [
              {
                'latitude': loc.latitude,
                'longitude': loc.longitude,
                'timestamp': loc.timestamp,
              }
            ],
          };
          lastPhotoTime = thisPhotoTime;
        } else {
          // Check date difference
          final difference = thisPhotoTime.difference(lastPhotoTime!).inDays;
          if (difference.abs() <= dayGap) {
            // Belongs to current trip
            currentTrip['locations'].add({
              'latitude': loc.latitude,
              'longitude': loc.longitude,
              'timestamp': loc.timestamp,
            });
            // Update end date
            currentTrip['timeframe']['end'] = loc.timestamp;
          } else {
            // Finish current trip, add to trips
            trips.add(currentTrip);
            // Start a new trip
            final city = findClosestCity(loc.latitude, loc.longitude);
            final cityName = city?.name ?? 'Unknown';

            currentTrip = {
              'id': _generateTripId(),
              'title': cityName,
              'timeframe': {
                'start': loc.timestamp,
                'end': loc.timestamp,
              },
              'locations': [
                {
                  'latitude': loc.latitude,
                  'longitude': loc.longitude,
                  'timestamp': loc.timestamp,
                }
              ],
            };
          }
          lastPhotoTime = thisPhotoTime;
        }
      }

      // Add the last trip
      if (currentTrip != null) {
        trips.add(currentTrip);
      }

      print("Created ${trips.length} trips.");

      // 6) Save trips to Firebase: 'users/{uid}/trips'
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'trips': trips,
      }, SetOptions(merge: true));

      print("Trips saved to 'users/{uid}/trips'.");
    } catch (e) {
      print('Error fetching photo metadata: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error fetching photo metadata.')),
      );
    }
  }

  /// Private helper to generate a random trip ID like "#a1b2c"
  static String _generateTripId() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rnd = math.Random();
    final sb = StringBuffer('#');
    for (int i = 0; i < 5; i++) {
      sb.write(chars[rnd.nextInt(chars.length)]);
    }
    return sb.toString();
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
