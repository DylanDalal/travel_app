// lib/user_data/data_operations.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle; // For loading JSON
import 'dart:convert'; // For jsonDecode
import 'dart:math' as math; // For haversineDistance
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:photo_manager/photo_manager.dart' as photo_manager;
import 'package:intl/intl.dart';

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

/// Responsible for retrieving photo metadata from the device, city lookup, etc.
class CustomPhotoManager {
  /// Master list of all known cities. Populated by loadAllCityDatasets().
  static List<City> allCities = [];

  /// Load city data from multiple JSON files
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
        final dataString = await rootBundle.loadString(filePath);
        final List<dynamic> jsonList = jsonDecode(dataString);

        for (var item in jsonList) {
          final name = item['name'] as String?;
          final lat = item['latitude']?.toDouble();
          final lon = item['longitude']?.toDouble();

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
  static City? findClosestCity(double lat, double lon) {
    if (allCities.isEmpty) {
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

  static double _haversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371; // Earth in km
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

  /// Fetch location data from the device and build + save trips in Firebase.
  /// Does NOT require the map to be initialized (no pins plotted here).
  static Future<void> fetchPhotoMetadata({
    required BuildContext context,
    required DateTimeRange timeframe,
  }) async {
    // 1) Check timeframe
    if (timeframe == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a timeframe first.')),
      );
      return;
    }

    // 2) Request photo permission
    final photo_manager.PermissionState state =
        await photo_manager.PhotoManager.requestPermissionExtend();
    if (!state.isAuth) {
      print('Photo access denied.');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photo access is required to fetch photos.')),
      );
      return;
    }

    try {
      // 3) Load city datasets (for findClosestCity)
      await loadAllCityDatasets();

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print("No authenticated user found. Cannot proceed.");
        return;
      }

      // 4) Fetch photos from the device
      final albums = await photo_manager.PhotoManager.getAssetPathList(
        type: photo_manager.RequestType.image,
      );

      if (albums.isEmpty) {
        print('No photo albums found.');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No photo albums found.')),
        );
        return;
      }

      final photo_manager.AssetPathEntity firstAlbum = albums[0];
      final userPhotos = await firstAlbum.getAssetListPaged(page: 0, size: 100);

      if (userPhotos.isEmpty) {
        print('No photos found in the album.');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No photos found in the album.')),
        );
        return;
      }

      // 5) Build photoLocations by timeframe
      List<Location> photoLocations = [];
      final start = timeframe.start;
      final end = timeframe.end;

      for (final asset in userPhotos) {
        final lat = asset.latitude ?? 0.0;
        final lon = asset.longitude ?? 0.0;
        final createTime = asset.createDateTime;

        if (lat != 0.0 &&
            lon != 0.0 &&
            createTime.isAfter(start) &&
            createTime.isBefore(end)) {
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
        }
      }

      if (photoLocations.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No photos found within that timeframe.')),
        );
        return;
      }

      // 6) Build trips from these photoLocations
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
          final firstCity = findClosestCity(loc.latitude, loc.longitude);
          final firstCityName = firstCity?.name ?? 'Unknown';

          currentTrip = {
            'id': _generateTripId(),
            'title': firstCityName, // Initial title with just first city
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
          final difference = thisPhotoTime.difference(lastPhotoTime!).inDays;
          if (difference.abs() <= dayGap) {
            // Same trip
            currentTrip['locations'].add({
              'latitude': loc.latitude,
              'longitude': loc.longitude,
              'timestamp': loc.timestamp,
            });
            currentTrip['timeframe']['end'] = loc.timestamp;

            // Update title based on number of locations
            final locations = currentTrip['locations'] as List;
            if (locations.length == 2) {
              // For exactly 2 locations: "City1 and City2"
              final firstLoc = locations.first;
              final lastLoc = locations.last;
              final firstCity = findClosestCity(firstLoc['latitude'], firstLoc['longitude']);
              final lastCity = findClosestCity(lastLoc['latitude'], lastLoc['longitude']);
              currentTrip['title'] = '${firstCity?.name ?? "Unknown"} and ${lastCity?.name ?? "Unknown"}';
            } else if (locations.length > 2) {
              // For 3+ locations: "City1 to CityN"
              final firstLoc = locations.first;
              final lastLoc = locations.last;
              final firstCity = findClosestCity(firstLoc['latitude'], firstLoc['longitude']);
              final lastCity = findClosestCity(lastLoc['latitude'], lastLoc['longitude']);
              currentTrip['title'] = '${firstCity?.name ?? "Unknown"} to ${lastCity?.name ?? "Unknown"}';
            }
          } else {
            // Start new trip
            trips.add(currentTrip);
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
      if (currentTrip != null) {
        trips.add(currentTrip);
      }

      print("Created ${trips.length} trips from device photos.");

      // 7) Save trips to Firebase
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'trips': trips,
      }, SetOptions(merge: true));

      print("Trips saved to 'users/{uid}/trips'.");
    } catch (e) {
      print('Error fetching photo metadata: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching photo metadata.')),
      );
    }
  }

  /// Plot existing trips from Firebase onto the map.
  /// Requires the map to be initialized, but does NOT read from the device.
  static Future<void> plotPhotoMetadata({
    required BuildContext context,
    required MapManager mapManager,
  }) async {
    if (!mapManager.isInitialized) {
      print('Map is not initialized; cannot plot pins.');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print("No authenticated user found.");
      return;
    }

    try {
      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (!userDoc.exists) {
        print("User doc doesn't exist, no trips to plot.");
        return;
      }

      final List<dynamic> tripsData = userDoc.data()?['trips'] ?? [];
      if (tripsData.isEmpty) {
        print('No trips found to plot.');
        return;
      }

      List<Location> allLocations = [];
      for (final trip in tripsData) {
        final locs = trip['locations'] ?? [];
        for (final loc in locs) {
          allLocations.add(Location(
            latitude: loc['latitude'],
            longitude: loc['longitude'],
            timestamp: loc['timestamp'],
          ));
        }
      }

      if (allLocations.isEmpty) {
        print('No photo locations in the stored trips.');
        return;
      }

      // Clear existing pins and plot all locations at once
      await mapManager.clearAllPins();
      print("Cleared existing pins before plotting.");
      
      print("Plotting ${allLocations.length} locations...");
      await mapManager.plotLocationsOnMap(allLocations);
    } catch (e) {
      print('Error plotting trips: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error plotting photo metadata.')),
        );
      }
    }
  }

  /// Generate random ID like "#a1b2c"
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
