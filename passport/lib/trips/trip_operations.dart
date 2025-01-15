/// A helper class that encapsulates the logic for
/// creating, editing, merging, and splitting trips.
/// Each method returns an updated list of trips so the caller
/// can setState(...) with the result.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';  // for UniqueKey, etc.
import '../my_trips_section.dart'; 
import '../classes.dart'; // Import Location class

class TripOperations {
  /// CREATE a brand new trip in Firestore and return updated trips.
  static Future<List<Map<String, dynamic>>> createTrip({
    required String userUID,
    required List<Map<String, dynamic>> currentTrips,
    required String title,
    required DateTimeRange timeframe,
    required List<Location> locations,
  }) async {
    final userDoc = FirebaseFirestore.instance.collection('users').doc(userUID);

    // Build the new trip object
    final newTrip = {
      "id": UniqueKey().toString(),
      "title": title,
      "timeframe": {
        "start": timeframe.start.toIso8601String(),
        "end": timeframe.end.toIso8601String(),
      },
      "locations": locations
          .map((loc) => {
                "latitude": loc.latitude,
                "longitude": loc.longitude,
                "timestamp": loc.timestamp,
              })
          .toList(),
    };

    // Add to Firestore array
    final updatedTrips = List<Map<String, dynamic>>.from(currentTrips);
    updatedTrips.add(newTrip);

    await userDoc.set({'trips': updatedTrips}, SetOptions(merge: true));
    return updatedTrips;
  }

  /// EDIT/UPDATE an existing trip in Firestore and return updated trips.
  static Future<List<Map<String, dynamic>>> editTrip({
    required String userUID,
    required List<Map<String, dynamic>> currentTrips,
    required String editingTripId,
    required String title,
    required DateTimeRange timeframe,
    required List<Location> locations,
  }) async {
    final userDoc = FirebaseFirestore.instance.collection('users').doc(userUID);

    // Update the matching trip
    final updatedTrips = currentTrips.map((trip) {
      if (trip['id'] == editingTripId) {
        return {
          "id": editingTripId,
          "title": title,
          "timeframe": {
            "start": timeframe.start.toIso8601String(),
            "end": timeframe.end.toIso8601String(),
          },
          "locations": locations
              .map((loc) => {
                    "latitude": loc.latitude,
                    "longitude": loc.longitude,
                    "timestamp": loc.timestamp,
                  })
              .toList(),
        };
      }
      return trip;
    }).toList();

    await userDoc.set({'trips': updatedTrips}, SetOptions(merge: true));
    return updatedTrips.cast<Map<String, dynamic>>();
  }

  /// MERGE multiple selected trips into one new trip. 
  /// If deleteOldTrips == true, remove those old trips.
  /// Returns updated list of trips.
  static Future<List<Map<String, dynamic>>> mergeTrips({
    required String userUID,
    required List<Map<String, dynamic>> currentTrips,
    required Set<String> selectedTripIds,
    required String mergedTripName,
    required bool deleteOldTrips,
  }) async {
    final selected = currentTrips
        .where((trip) => selectedTripIds.contains(trip['id']))
        .toList();
    if (selected.isEmpty) return currentTrips;

    // Earliest / Latest
    DateTime? earliest;
    DateTime? latest;

    // We'll combine other fields (except id, timeframe, title)
    final mergedData = <String, dynamic>{};

    for (var trip in selected) {
      final startStr = trip['timeframe']?['start'];
      final endStr = trip['timeframe']?['end'];
      if (startStr != null && endStr != null) {
        final sDate = DateTime.parse(startStr);
        final eDate = DateTime.parse(endStr);
        if (earliest == null || sDate.isBefore(earliest)) earliest = sDate;
        if (latest == null || eDate.isAfter(latest)) latest = eDate;
      }

      // Merge other keys
      trip.forEach((key, value) {
        if (key == 'id' || key == 'timeframe' || key == 'title') return;

        if (!mergedData.containsKey(key)) {
          mergedData[key] = value;
        } else {
          // If both are lists, union them
          if (mergedData[key] is List && value is List) {
            mergedData[key].addAll(value);
          } else {
            // Otherwise last-write-wins
            mergedData[key] = value;
          }
        }
      });
    }

    // Build timeframe
    final mergedTimeframe = {
      "start": earliest?.toIso8601String() ?? DateTime.now().toIso8601String(),
      "end": latest?.toIso8601String() ?? DateTime.now().toIso8601String(),
    };

    // Build the new merged trip
    final newTrip = {
      ...mergedData,
      "id": UniqueKey().toString(),
      "title": mergedTripName,
      "timeframe": mergedTimeframe,
    };

    // Create the updated list
    final updatedTrips = deleteOldTrips
        ? currentTrips.where((t) => !selectedTripIds.contains(t['id'])).toList()
        : List<Map<String, dynamic>>.from(currentTrips);

    updatedTrips.add(newTrip);

    // Write to Firestore
    final userDoc = FirebaseFirestore.instance.collection('users').doc(userUID);
    await userDoc.set({'trips': updatedTrips}, SetOptions(merge: true));
    return updatedTrips;
  }

  /// SPLIT a single trip (identified by editingTripId) at [splitDate].
  /// Everything after [splitDate] goes into a new trip named "originalTitle 2".
  /// Returns updated list of trips.
  static Future<List<Map<String, dynamic>>> splitTrip({
    required String userUID,
    required List<Map<String, dynamic>> currentTrips,
    required String editingTripId,
    required DateTime splitDate,
  }) async {
    final idx = currentTrips.indexWhere((t) => t['id'] == editingTripId);
    if (idx < 0) {
      print("Trip not found with ID $editingTripId");
      return currentTrips;
    }

    final originalTrip = currentTrips[idx];
    final originalTitle = originalTrip['title'] ?? 'Untitled Trip';
    final timeframeMap = originalTrip['timeframe'] as Map<String, dynamic>?;
    if (timeframeMap == null) {
      print("No timeframe in trip. Cannot split.");
      return currentTrips;
    }

    final startIso = timeframeMap['start'];
    final endIso = timeframeMap['end'];
    if (startIso == null || endIso == null) {
      print("Incomplete timeframe data. Cannot split.");
      return currentTrips;
    }

    final startDate = DateTime.parse(startIso);
    final endDate = DateTime.parse(endIso);

    if (splitDate.isBefore(startDate) || splitDate.isAfter(endDate)) {
      print("Split date is outside the trip timeframe!");
      return currentTrips;
    }

    // Rebuild the original's timeframe
    final updatedOriginalTimeframe = {
      'start': startDate.toIso8601String(),
      'end': splitDate.toIso8601String(),
    };

    final newTimeframe = {
      'start': splitDate.toIso8601String(),
      'end': endDate.toIso8601String(),
    };

    // Move data after split
    final originalLocations = (originalTrip['locations'] ?? []) as List<dynamic>;
    final List<dynamic> newLocations = [];
    final List<dynamic> updatedOriginalLocations = [];

    for (var loc in originalLocations) {
      if (loc is Map<String, dynamic>) {
        final tsStr = loc['timestamp'] as String?;
        if (tsStr != null) {
          final locDate = DateTime.parse(tsStr);
          if (locDate.isAfter(splitDate)) {
            newLocations.add(loc);
            continue;
          }
        }
      }
      updatedOriginalLocations.add(loc);
    }

    // Make a copy of the original trip
    final newTrip = Map<String, dynamic>.from(originalTrip);
    newTrip['id'] = UniqueKey().toString();
    newTrip['title'] = originalTitle + " 2";
    newTrip['timeframe'] = newTimeframe;
    newTrip['locations'] = newLocations;

    // Update the original
    final updatedOriginalTrip = Map<String, dynamic>.from(originalTrip);
    updatedOriginalTrip['timeframe'] = updatedOriginalTimeframe;
    updatedOriginalTrip['locations'] = updatedOriginalLocations;

    // Build updated list
    final updatedTrips = List<Map<String, dynamic>>.from(currentTrips);
    updatedTrips[idx] = updatedOriginalTrip;
    updatedTrips.add(newTrip);

    // Write to Firestore
    final userDoc = FirebaseFirestore.instance.collection('users').doc(userUID);
    await userDoc.set({'trips': updatedTrips}, SetOptions(merge: true));

    return updatedTrips;
  }
}
