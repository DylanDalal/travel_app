/*

      Testing suite for data operations
      Generates random email for use in firebase

*/



import 'dart:math'; // For generating random strings
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'data_operations.dart';
import '../classes.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Generate a random email
  final random = Random();
  final randomString = String.fromCharCodes(
    List.generate(8, (index) => random.nextInt(26) + 97), // Generates 8 random lowercase letters
  );
  final email = "$randomString@dev.com";
  final password = "tester1"; 

  try {
    // Create a test user and get their user ID
    final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final testUserId = userCredential.user?.uid;

    if (testUserId == null) {
      print("Failed to retrieve user ID.");
      return;
    }

    final DateTimeRange testTimeframe = DateTimeRange(
      start: DateTime.now().subtract(Duration(days: 30000)),
      end: DateTime.now(),
    );

    print('Starting tests...');
    print('Using email: $email');
    await testPhotoManager();
    await testDataSaver(testUserId);
    await testDataFetcher(testUserId, testTimeframe);
    print('Tests completed.');
  } catch (e) {
    print('Error during authentication: $e');
  }
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
