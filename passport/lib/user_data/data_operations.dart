// lib/user_data/data_operations.dart

import 'dart:async'; // Import for Timer
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart' as photo;

// Import the PermissionUtils class
import '../utils/permission_utils.dart'; // Adjust the path based on your project structure

import '../trips/map_manager.dart'; // Import MapManager
import '../classes.dart'; // For the Location class, etc.

/*
    ===  Class DataFetcher ===
    Responsible for retrieving a user's data from Firebase.
*/
class DataFetcher {
  /// Fetch photo metadata stored in Firebase for a given timeframe
  static Future<List<Location>> fetchPhotoMetadataFromFirebase(
      String userId, DateTimeRange timeframe) async {
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
              closestCity: data['closestCity'] ?? 'Unknown',
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

/*
    ===  Class DataSaver ===
    Responsible for saving a user's data to Firebase.
*/
class DataSaver {
  /// Save photo metadata to Firebase
  static Future<void> savePhotoMetadataToFirebase(
      String userId, List<Location> photoLocations) async {
    final userDoc =
        FirebaseFirestore.instance.collection('users').doc(userId);

    // Prepare data for Firebase
    List<Map<String, dynamic>> locationData = photoLocations
        .map((location) => {
              'latitude': location.latitude,
              'longitude': location.longitude,
              'timestamp': location.timestamp,
              'closestCity': location.closestCity,
            })
        .toList();
    print('Saving to Firebase: $locationData');

    // Store data in Firestore
    await userDoc
        .set({'photoLocations': locationData}, SetOptions(merge: true));
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

      // Request photo permissions
      bool photoAccessGranted =
          await PermissionUtils.requestPhotoPermission();
      if (!photoAccessGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Photo access is required to upload your photos.',
            ),
          ),
        );
        PermissionUtils.openSettingsIfNeeded();
        return;
      }

      // Fetch and save photo metadata
      final List<Location> photoMetadata =
          await CustomPhotoManager.fetchAllPhotoMetadata();
      await savePhotoMetadataToFirebase(userId, photoMetadata);

      // Navigate to the Welcome Screen
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
    Responsible for locally retrieving photo metadata / dealing with permissions
*/
class CustomPhotoManager {
  /// Request photo library access using `photo_manager` and return the state
  static Future<photo.PermissionState> requestPhotoPermission() async {
    final photo.PermissionState state =
        await photo.PhotoManager.requestPermissionExtend();

    if (state == photo.PermissionState.authorized) {
      print('Photo access granted');
    } else if (state == photo.PermissionState.limited) {
      print('Photo access granted with limitations');
    } else {
      print('Photo access denied');
    }
    return state;
  }

  /// Handle denied permissions by opening settings only if explicitly requested
  static Future<void> openSettingsIfNeeded(BuildContext context) async {
    final photo.PermissionState state =
        await photo.PhotoManager.requestPermissionExtend();
    if (state == photo.PermissionState.denied ||
        state == photo.PermissionState.restricted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Photo Access Required'),
          content: Text('To continue using the app, please grant photo access.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                photo.PhotoManager.openSetting();
              },
              child: Text('Open Settings'),
            ),
          ],
        ),
      );
    }
  }

  /// Fetch all photo metadata across the entire device
  static Future<List<Location>> fetchAllPhotoMetadata() async {
    final photo.PermissionState state = await requestPhotoPermission();
    if (!state.hasAccess) {
      throw Exception('Photo access denied.');
    }

    // Fetch albums
    List<photo.AssetPathEntity> albums =
        await photo.PhotoManager.getAssetPathList(
      type: photo.RequestType.image,
    );

    if (albums.isEmpty) {
      throw Exception('No photo albums found.');
    }

    List<Location> photoLocations = [];
    for (photo.AssetPathEntity album in albums) {
      List<photo.AssetEntity> userPhotos =
          await album.getAssetListPaged(page: 0, size: 500);

      for (photo.AssetEntity photoEntity in userPhotos) {
        if (photoEntity.latitude != null && photoEntity.longitude != null) {
          photoLocations.add(Location(
            latitude: photoEntity.latitude!,
            longitude: photoEntity.longitude!,
            timestamp: photoEntity.createDateTime.toIso8601String(),
            closestCity: 'Unknown', // Will be updated later
          ));
        }
      }
    }

    return photoLocations;
  }

  /// Show an in-app permission request dialog
  static void _showPermissionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Photo Access Required'),
        content: Text(
            'This app requires access to your photos to provide location-based tracking. Please allow access.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              photo.PhotoManager.openSetting();
            },
            child: Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  /// Fetch and plot photo metadata on the map
  static Future<void> fetchAndPlotPhotoMetadata(
      BuildContext context, MapManager mapManager, DateTimeRange timeframe) async {
    if (timeframe == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a timeframe first.')),
      );
      return;
    }

    // Check if MapManager is initialized
    if (!mapManager.isInitialized) {
      print("MapManager not initialized yet.");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Map is not ready yet. Please try again shortly.')),
      );
      return;
    }

    final photo.PermissionState state =
        await photo.PhotoManager.requestPermissionExtend();
    print('Photo permission state: $state');

    if (!state.isAuth) {
      print('Photo access denied.');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Photo access is required to fetch photos.')),
      );
      return;
    }

    try {
      List<photo.AssetPathEntity> albums =
          await photo.PhotoManager.getAssetPathList(
        type: photo.RequestType.image,
      );

      if (albums.isEmpty) {
        print('No photo albums found.');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No photo albums found.')),
        );
        return;
      }

      photo.AssetPathEntity recentAlbum = albums[0];
      List<photo.AssetEntity> userPhotos =
          await recentAlbum.getAssetListPaged(page: 0, size: 100);

      if (userPhotos.isEmpty) {
        print('No photos found in the album.');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No photos found in the album.')),
        );
        return;
      }

      List<Location> photoLocations = [];
      final start = timeframe.start;
      final end = timeframe.end;

      for (photo.AssetEntity photoEntity in userPhotos) {
        if (photoEntity.latitude != null &&
            photoEntity.longitude != null &&
            photoEntity.latitude != 0.0 &&
            photoEntity.longitude != 0.0 &&
            photoEntity.createDateTime.isAfter(start) &&
            photoEntity.createDateTime.isBefore(end)) {
          // Find the closest city using the MapManager instance
          City? closestCity = mapManager.findClosestCity(
              photoEntity.latitude!, photoEntity.longitude!);

          // Print the closest city
          if (closestCity != null) {
            print(
                "Closest city for photo at (${photoEntity.latitude}, ${photoEntity.longitude}) is: ${closestCity.name}");
          } else {
            print(
                "No closest city found for photo at (${photoEntity.latitude}, ${photoEntity.longitude}).");
          }

          // Add photo metadata and closest city to photoLocations
          photoLocations.add(Location(
            latitude: photoEntity.latitude!,
            longitude: photoEntity.longitude!,
            timestamp: photoEntity.createDateTime.toIso8601String(),
            closestCity: closestCity?.name ?? 'Unknown', // Include closest city
          ));
        } else {
          print(
              "Skipping invalid photo: ${photoEntity.latitude}, ${photoEntity.longitude}");
        }
      }

      if (photoLocations.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No photos found in the selected timeframe.')),
        );
      } else {
        print("Plotting ${photoLocations.length} locations on the map.");
        await mapManager.plotLocationsOnMap(photoLocations);

        // Save to Firebase
        final List<Map<String, dynamic>> firebaseData =
            photoLocations.map((location) => location.toMap()).toList();

        print("Saving to Firebase: $firebaseData");

        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await FirebaseFirestore.instance
              .collection('user_photos')
              .doc(user.uid) // Use the actual user's UID
              .set({'photos': firebaseData}, SetOptions(merge: true));

          print("Photo data with closest city saved to Firebase.");
        } else {
          print("No authenticated user found. Cannot save to Firebase.");
        }
      }
    } catch (e, stack) {
      print('Error fetching photo metadata: $e');
      print(stack);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching photo metadata.')),
      );
    }
  }
}
