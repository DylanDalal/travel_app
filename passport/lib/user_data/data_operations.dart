import 'package:photo_manager/photo_manager.dart' as photo;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'data_operations.dart';
import '../classes.dart';
import 'package:flutter/material.dart';


/*
    ===  Class DataFetcher ===
    Responsible for retrieving a users data from firebase.
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
    Responsible for saving a users data to firebase.
*/
class DataSaver {
  
  static Future<void> savePhotoMetadataToFirebase(
      String userId, List<Location> photoLocations) async {
    final userDoc = FirebaseFirestore.instance.collection('users').doc(userId);

    // Prepare data for Firebase
    List<Map<String, dynamic>> locationData = photoLocations
        .map((location) => {
              'latitude': location.latitude,
              'longitude': location.longitude,
              'timestamp': location.timestamp,
            })
        .toList();

    // Store data in Firestore
    await userDoc.set({'photoLocations': locationData}, SetOptions(merge: true));
  }

}

/*
    ===  Class PhotoManager ===
    Responsible for locally retrieving photo metadata
*/
class PhotoManager {
  /// Fetch all photo metadata across entire device
  static Future<List<Location>> fetchAllPhotoMetadata() async {
    final photo.PermissionState state =
        await photo.PhotoManager.requestPermissionExtend();
    if (!state.isAuth) {
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
          ));
        }
      }
    }

    return photoLocations;
  }
}