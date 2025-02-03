// lib/services/photo_trip_service.dart

import 'package:flutter/material.dart';
import 'package:passport/trips/map_manager.dart';
import 'package:photo_manager/photo_manager.dart' as photo;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:passport/user_data/data_operations.dart';
import 'package:passport/classes.dart';
import 'package:passport/home_screen.dart';
import 'permission_utils.dart';

class PhotoTripService {
  final MapManager mapManager;

  PhotoTripService({required this.mapManager});

  Future<void> grantPhotoAccess(BuildContext context, List<String> hometowns) async {
    final bool photoAccessGranted = await PermissionUtils.requestPhotoPermission();

    if (photoAccessGranted) {
      print('Photo access granted');

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (userDoc.exists && userDoc.data()?['hasPhotoMetadata'] == true) {
        print("Photo metadata already exists. Skipping re-upload.");
        // Optionally, you can navigate to HomeScreen or refresh data
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => HomeScreen()),
        );
        return;
      }

      // Save hometowns to Firebase
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'hometowns': hometowns,
      }, SetOptions(merge: true));

      // Fetch and process photos
      List<Location> fetchedPhotos = await CustomPhotoManager.fetchAllPhotoMetadata();
      await DataSaver.savePhotoMetadataToFirebase(user.uid, fetchedPhotos);
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
        {'hasPhotoMetadata': true},
        SetOptions(merge: true),
      );

      print('Saved photo metadata successfully.');

      // Plot the photos immediately after saving
      await CustomPhotoManager.fetchAndPlotPhotoMetadata(
        context,
        mapManager,
        DateTimeRange(
          start: DateTime.now().subtract(Duration(days: 10000)),
          end: DateTime.now(),
        ),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Your photos have been saved and plotted!')),
      );

      // Navigate to HomeScreen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomeScreen()),
      );
    } else if (photo.PermissionState.limited == photo.PermissionState.limited) {
      print('Photo access is limited.');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Limited access granted, some photos may be missing.')),
      );
    } else {
      print('Photo access denied');
      _showPermissionDialog(context);
    }
  }

  void _showPermissionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Photo Access Required'),
        content: Text(
            'This app requires photo access to upload and plot your photos. Would you like to allow access now?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              PermissionUtils.openSettingsIfNeeded();
            },
            child: Text('Open Settings'),
          ),
        ],
      ),
    );
  }
}
