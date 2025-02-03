// lib/user_data/data_operations.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:photo_manager/photo_manager.dart';
import '../trips/map_manager.dart';
import '../classes.dart'; // Import your data models
import '../utils/permission_utils.dart'; // Import permission utilities if any

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
            ))
        .where((location) {
          final timestamp = DateTime.parse(location.timestamp);
          return timestamp.isAfter(timeframe.start) &&
              timestamp.isBefore(timeframe.end);
        })
        .toList();

    return filteredLocations;
  }

  /// Fetch and plot photo metadata
  static Future<void> fetchAndPlotPhotoMetadata(
      BuildContext context, MapManager mapManager, DateTimeRange timeframe) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('No authenticated user found.');
      }

      // Fetch photo metadata from Firebase
      List<Location> photoLocations =
          await fetchPhotoMetadataFromFirebase(user.uid, timeframe);

      if (photoLocations.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No photo metadata found in the selected timeframe.')),
        );
        return;
      }

      // Plot locations on the map
      await mapManager.plotLocationsOnMap(photoLocations);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Your trips have been loaded successfully!')),
      );
    } catch (e) {
      print('Error in fetchAndPlotPhotoMetadata: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load trips: $e')),
      );
    }
  }
}

class DataSaver {
  /// Save photo metadata to Firebase
  static Future<void> savePhotoMetadataToFirebase(
      String userId, List<Location> photoLocations) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).set({
        'photoLocations': photoLocations.map((loc) => loc.toMap()).toList(),
      }, SetOptions(merge: true));
      print('Photo metadata saved to Firebase.');
    } catch (e) {
      print('Error saving photo metadata: $e');
    }
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
        await CustomPhotoManager.openSettingsIfNeeded(context);
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

class CustomPhotoManager {
  /// Fetch all photo metadata
  static Future<List<Location>> fetchAllPhotoMetadata() async {
    List<Location> locations = [];
    try {
      // Request permission
      final PermissionState permission = await PhotoManager.requestPermissionExtend();
      if (!permission.isAuth) {
        print('Photo access denied.');
        return locations;
      }

      // Fetch all albums
      final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
        type: RequestType.image,
        hasAll: true,
      );

      for (final AssetPathEntity album in albums) {
        // Fetch all photos in the album
        // Adjusted to use named parameters if required
        final List<AssetEntity> photos = await album.getAssetListPaged(page: 0, size: 10000);
        for (final AssetEntity photo in photos) {
          if (photo.latitude != null && photo.longitude != null) {
            final double latitude = photo.latitude!;
            final double longitude = photo.longitude!;
            final DateTime date = photo.createDateTime;

            // Create Location object
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

  /// Fetch and plot photo metadata on the map
  static Future<void> fetchAndPlotPhotoMetadata(
      BuildContext context, MapManager mapManager, DateTimeRange timeframe) async {
    try {
      // Fetch photo metadata
      final List<Location> locations = await fetchAllPhotoMetadata();

      if (locations.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No photo metadata found.')),
        );
        return;
      }

      // Optionally, filter locations based on the timeframe
      final List<Location> filteredLocations = locations.where((location) {
        final DateTime photoDate = DateTime.parse(location.timestamp);
        return photoDate.isAfter(timeframe.start) && photoDate.isBefore(timeframe.end);
      }).toList();

      if (filteredLocations.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No photos found in the selected timeframe.')),
        );
        return;
      }

      // Plot locations on the map
      await mapManager.plotLocationsOnMap(filteredLocations);

      // Save to Firebase if needed
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('user_photos').doc(user.uid).set({
          'photos': filteredLocations.map((loc) => loc.toMap()).toList(),
        }, SetOptions(merge: true));
        print("Photo data saved to Firebase.");
      } else {
        print("No authenticated user found. Cannot save to Firebase.");
      }
    } catch (e) {
      print('Error fetching and plotting photo metadata: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching and plotting photo metadata.')),
      );
    }
  }

  /// Open app settings to grant photo access
  static Future<void> openSettingsIfNeeded(BuildContext context) async {
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
              PhotoManager.openSetting();
            },
            child: Text('Open Settings'),
          ),
        ],
      ),
    );
  }
}
