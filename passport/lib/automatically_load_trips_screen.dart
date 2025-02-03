// lib/automatically_load_trips_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart'; // Import for TypeAheadField
import 'package:http/http.dart' as http; // Import the http package
import 'dart:convert'; // Import for json decoding
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Import your custom classes
import '../user_data/data_operations.dart'; // Import DataSaver and CustomPhotoManager
import '../trips/map_manager.dart'; // Import MapManager
import '../home_screen.dart'; // Import HomeScreen
import '../classes.dart'; // Import Location and City

class AutomaticallyLoadTripsScreen extends StatefulWidget {
  const AutomaticallyLoadTripsScreen({Key? key}) : super(key: key);

  @override
  _AutomaticallyLoadTripsScreenState createState() => _AutomaticallyLoadTripsScreenState();
}

class _AutomaticallyLoadTripsScreenState extends State<AutomaticallyLoadTripsScreen> {
  List<String> hometowns = [];
  final TextEditingController _hometownController = TextEditingController();
  final MapManager _mapManager = MapManager(onPlotComplete: () {
    print('Map plotting completed successfully.');
  });

  final String mapboxAccessToken = 'sk.eyJ1IjoiY29ubm9yY2FtcDEyIiwiYSI6ImNtNW42bjJ1cDA4MGUybm9tM3cxNWdwMnUifQ.74B36OWlxmAAfrqSkA_zRA';

  @override
  void dispose() {
    _hometownController.dispose();
    super.dispose();
  }

  void _addHometown(String hometown) {
    if (hometown.isNotEmpty && !hometowns.contains(hometown)) {
      setState(() {
        hometowns.add(hometown);
      });
    }
  }

  void _removeHometown(String hometown) {
    setState(() {
      hometowns.remove(hometown);
    });
  }

  Future<List<String>> _fetchHometownSuggestions(String query) async {
    if (query.length < 3) {
      return [];
    }

    final url =
        'https://api.mapbox.com/geocoding/v5/mapbox.places/${Uri.encodeComponent(query)}.json?types=place&access_token=$mapboxAccessToken&autocomplete=true&language=en';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List features = data['features'];
        return features.map<String>((feature) => feature['place_name'] as String).toList();
      } else {
        print('Mapbox API Error: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Error fetching hometown suggestions: $e');
      return [];
    }
  }

  Future<void> _grantPhotoAccess() async {
    if (hometowns.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please add at least one hometown.')),
      );
      return;
    }

    // Save hometowns to Firebase
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('User not authenticated.')),
      );
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'hometowns': hometowns,
      }, SetOptions(merge: true));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save hometowns: $e')),
      );
      return;
    }

    // Define the timeframe as needed
    final DateTimeRange timeframe = DateTimeRange(
      start: DateTime.now().subtract(Duration(days: 365)), // Example: past year
      end: DateTime.now(),
    );

    // Call fetchAndPlotPhotoMetadata from CustomPhotoManager within data_operations.dart
    await CustomPhotoManager.fetchAndPlotPhotoMetadata(
      context,
      _mapManager,
      timeframe,
    );

    // Navigate to HomeScreen
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Automatically Load Trips'),
        automaticallyImplyLeading: false, // Prevent back navigation
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              "Passport will automatically load your past trips based on location data attached to your photos. None of these photos are ever visible to us or stored in our database—we only access the location metadata. You may also manually select and limit the pictures that Passport creates trips from by allowing selective photo access.",
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 24),
            // Hometowns Input Field with Autocomplete
            TypeAheadField(
              textFieldConfiguration: TextFieldConfiguration(
                controller: _hometownController,
                decoration: InputDecoration(
                  labelText: 'Enter Hometown',
                  border: OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(Icons.add),
                    onPressed: () {
                      _addHometown(_hometownController.text.trim());
                      _hometownController.clear();
                    },
                  ),
                ),
              ),
              suggestionsCallback: (pattern) async {
                return await _fetchHometownSuggestions(pattern);
              },
              itemBuilder: (context, String suggestion) {
                return ListTile(
                  title: Text(suggestion),
                );
              },
              onSuggestionSelected: (String suggestion) {
                _addHometown(suggestion);
                _hometownController.clear();
              },
              noItemsFoundBuilder: (context) => Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text('No suggestions found.'),
              ),
            ),
            SizedBox(height: 16),
            // Display Added Hometowns
            Wrap(
              spacing: 8.0,
              children: hometowns
                  .map((hometown) => Chip(
                        label: Text(hometown),
                        onDeleted: () => _removeHometown(hometown),
                      ))
                  .toList(),
            ),
            Spacer(),
            ElevatedButton(
              onPressed: _grantPhotoAccess,
              child: Text('Grant Photo Access'),
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 50), // Make button full width
              ),
            ),
          ],
        ),
      ),
    );
  }
}
