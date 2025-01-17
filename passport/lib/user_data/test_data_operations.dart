import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'data_operations.dart';
import 'package:flutter/material.dart';
import '../classes.dart';
import 'package:firebase_auth/firebase_auth.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Create a test user and get their user ID
  final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
    email: "devdev@dev.com",
    password: "tester1",
  );
  final testUserId = userCredential.user?.uid; // Extract the UID

  if (testUserId == null) {
    print("Failed to retrieve user ID.");
    return;
  }

  final DateTimeRange testTimeframe = DateTimeRange(
    start: DateTime.now().subtract(Duration(days: 30)),
    end: DateTime.now(),
  );

  print('Starting tests...');
  await testPhotoManager();
  await testDataSaver(testUserId); // Pass the extracted UID
  await testDataFetcher(testUserId, testTimeframe); // Pass the extracted UID
  print('Tests completed.');
}


Future<void> testPhotoManager() async {
  print('Testing PhotoManager...');
  try {
    final List<Location> locations = await PhotoManager.fetchAllPhotoMetadata();
    print('Fetched ${locations.length} locations from the device.');
  } catch (e) {
    print('PhotoManager test failed: $e');
  }
}

Future<void> testDataSaver(String userId) async {
  print('Testing DataSaver...');
  try {
    final List<Location> sampleLocations = [
      Location(
        latitude: 37.7749,
        longitude: -122.4194,
        timestamp: DateTime.now().toIso8601String(),
      ),
    ];
    await DataSaver.savePhotoMetadataToFirebase(userId, sampleLocations);
    print('Saved sample photo metadata to Firebase.');
  } catch (e) {
    print('DataSaver test failed: $e');
  }
}

Future<void> testDataFetcher(String userId, DateTimeRange timeframe) async {
  print('Testing DataFetcher...');
  try {
    final List<Location> locations =
        await DataFetcher.fetchPhotoMetadataFromFirebase(userId, timeframe);
    print('Fetched ${locations.length} locations from Firebase.');
  } catch (e) {
    print('DataFetcher test failed: $e');
  }
}
