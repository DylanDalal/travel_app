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
  late MapManager _mapManager;
  late PhotoTripService _photoTripService;

  bool _dataFetched = false; // track if we've already loaded data

  @override
  void initState() {
    super.initState();

    _mapManager = MapManager(
      onPlotComplete: () {
        print('Map plotting completed successfully.');
        _mapManager.startRotatingGlobe();
      },
    );
  }

  Future<void> _initializeUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    print("Checking user data for: ${user.uid}");
    bool isFirstLogin = await _checkIfFirstLogin(user.uid);
  }

  Future<bool> _checkIfFirstLogin(String userId) async {
    try {
      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(userId).get();
      if (userDoc.exists && userDoc.data()?['hasPhotoMetadata'] == true) {
        return false; // Not first login
      }
      return true; // Possibly first login
    } catch (e) {
      print("Error checking first login: $e");
      return false;
    }
  }

  // Called by MyTripsSection once the map is definitely initialized
  void fetchDataWhenMapIsReady() {
    if (_dataFetched) {
      print("Data already fetched, skipping re-fetch.");
      return;
    }
    _dataFetched = true;

    CustomPhotoManager.plotPhotoMetadata(
      context: context,
      mapManager: _mapManager,
    );
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
        title: const Text('Home'),
        automaticallyImplyLeading: false,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.account_circle),
            onSelected: (value) {
              if (value == 'Profile') {
                Navigator.pushNamed(context, '/profile');
              } else if (value == 'Settings') {
                Navigator.pushNamed(context, '/settings');
              } else if (value == 'Logout') {
                _logout(context);
              }
            },
            itemBuilder: (BuildContext context) => const [
              PopupMenuItem(value: 'Profile', child: Text('Profile')),
              PopupMenuItem(value: 'Settings', child: Text('Settings')),
              PopupMenuItem(value: 'Logout', child: Text('Logout')),
            ],
          ),
        ],
      ),
      body: _currentIndex == 0
          ? MyTripsSection(
              mapManager: _mapManager,
              onMapInitialized: fetchDataWhenMapIsReady,
            )
          : FriendsSection(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() {
          _currentIndex = index;
        }),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'My Trips'),
          BottomNavigationBarItem(icon: Icon(Icons.group), label: 'Friends'),
        ],
      ),
    );
  }
}
