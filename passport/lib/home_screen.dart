// lib/home_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:passport/trips/map_manager.dart';
import 'package:passport/user_data/data_operations.dart';
import 'package:passport/utils/photo_trip_service.dart';
import 'friends_section.dart';
import 'classes.dart';
import 'my_trips_section.dart';
import 'utils/permission_utils.dart';

class HomeScreen extends StatefulWidget {
  final bool isManual; // Indicates if the user chose manual loading

  HomeScreen({this.isManual = false, Key? key}) : super(key: key);

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  List<Location> photoLocations = [];
  late MapManager _mapManager;
  late PhotoTripService _photoTripService;

  bool _dataFetched = false; // Add a flag to prevent re-fetching

  @override
  void initState() {
    super.initState();
    _mapManager = MapManager(
      onPlotComplete: () {
        print('Map plotting completed successfully.');
        if (!_dataFetched) {
          _fetchStoredPhotoData(FirebaseAuth.instance.currentUser!.uid);
        }
      },
    );
    _photoTripService = PhotoTripService(mapManager: _mapManager);
    _initializeUserData();
  }

  Future<void> _initializeUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    print("Checking user data for: ${user.uid}");
    bool isFirstLogin = await _checkIfFirstLogin(user.uid);
    if (isFirstLogin && !widget.isManual) {
      // If the user is not using manual loading, ensure photo data is handled
      // This scenario might not occur based on the new flow
    } else {
      print("Existing user, plotting stored photos.");
      if (!_dataFetched) {
        _fetchStoredPhotoData(user.uid);
      }
    }
  }

  Future<bool> _checkIfFirstLogin(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      if (userDoc.exists && userDoc.data()?['hasPhotoMetadata'] == true) {
        return false; // Not first login
      }
      return true; // First login
    } catch (e) {
      print("Error checking first login: $e");
      return false;
    }
  }

  Future<void> _fetchStoredPhotoData(String userId) async {
    if (_dataFetched) {
      print("Data already fetched, skipping re-fetch.");
      return;
    }

    if (!_mapManager.isInitialized) {
      print("Waiting for MapManager to initialize...");
      await Future.delayed(Duration(seconds: 2));
      _fetchStoredPhotoData(userId);
      return;
    }

    _dataFetched = true; // Set the flag after fetching to prevent looping

    final DateTimeRange timeframe = DateTimeRange(
      start: DateTime.now().subtract(Duration(days: 10000)),
      end: DateTime.now(),
    );

    print("Fetching and plotting photo data for user: $userId");

    try {
      await CustomPhotoManager.fetchAndPlotPhotoMetadata(context, _mapManager, timeframe);
      print("Photo data fetched and plotted successfully.");
    } catch (e) {
      print('Error fetching and plotting photo data: $e');
      _dataFetched = false; // Reset flag on failure
    }
  }

  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Home'),
        automaticallyImplyLeading: false,
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.account_circle),
            onSelected: (value) {
              if (value == 'Profile') {
                Navigator.pushNamed(context, '/profile');
              } else if (value == 'Settings') {
                Navigator.pushNamed(context, '/settings');
              } else if (value == 'Logout') {
                _logout(context);
              }
            },
            itemBuilder: (BuildContext context) => [
              PopupMenuItem(value: 'Profile', child: Text('Profile')),
              PopupMenuItem(value: 'Settings', child: Text('Settings')),
              PopupMenuItem(value: 'Logout', child: Text('Logout')),
            ],
          ),
        ],
      ),
      body: _currentIndex == 0
          ? MyTripsSection(mapManager: _mapManager)
          : FriendsSection(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'My Trips'),
          BottomNavigationBarItem(icon: Icon(Icons.group), label: 'Friends'),
        ],
      ),
    );
  }
}
