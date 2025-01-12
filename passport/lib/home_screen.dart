import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:photo_manager/photo_manager.dart'
    as photo; // Import photo_manager
import 'my_trips_section.dart';
import 'friends_section.dart';

class HomeScreen extends StatefulWidget {
  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  List<Location> photoLocations = []; // Declare photoLocations

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text('Home'),
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
      body: _currentIndex == 0 ? MyTripsSection() : FriendsSection(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'My Trips',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.group),
            label: 'Friends',
          ),
        ],
      ),
    );
  }

  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/');
  }

  Future<List<Location>> getUserPhotoData() async {
    // Request permissions
    final photo.PermissionState state =
        await photo.PhotoManager.requestPermissionExtend();
    if (!state.isAuth) {
      print('Photo access denied');
      return [];
    }

    // Fetch albums
    List<photo.AssetPathEntity> albums =
        await photo.PhotoManager.getAssetPathList(
      type: photo.RequestType.image,
    );

    List<Location> fetchedLocations = [];
    if (albums.isNotEmpty) {
      photo.AssetPathEntity recentAlbum = albums[0];
      List<photo.AssetEntity> userPhotos =
          await recentAlbum.getAssetListPaged(page: 0, size: 100);

      // Extract photo locations
      for (photo.AssetEntity photoEntity in userPhotos) {
        if (photoEntity.latitude != null && photoEntity.longitude != null) {
          fetchedLocations.add(Location(
            latitude: photoEntity.latitude!,
            longitude: photoEntity.longitude!,
          ));
        }
      }
    } else {
      print('No albums found.');
    }

    photoLocations = fetchedLocations; // Update class-level photoLocations
    return fetchedLocations;
  }
}

class Location {
  final double latitude;
  final double longitude;

  Location({required this.latitude, required this.longitude});
}
