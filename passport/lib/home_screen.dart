import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:photo_manager/photo_manager.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
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
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Welcome to your home screen!'),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: fetchAndPrintPhotoMetadata,
              child: Text('Fetch Photo Metadata'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> fetchAndPrintPhotoMetadata() async {
    final PermissionState state = await PhotoManager.requestPermissionExtend();
    if (!state.isAuth) {
      print('Photo access denied');
      return;
    }

    List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
      type: RequestType.image,
    );

    if (albums.isNotEmpty) {
      AssetPathEntity recentAlbum = albums[0];
      List<AssetEntity> photos =
          await recentAlbum.getAssetListPaged(page: 0, size: 100);

      for (AssetEntity photo in photos) {
        DateTime? creationDate = photo.createDateTime;
        String? title = photo.title;
        Location? location = photo.latitude != null && photo.longitude != null
            ? Location(latitude: photo.latitude!, longitude: photo.longitude!)
            : null;

        print('Photo: ${title ?? "Unnamed"}');
        print('Created on: $creationDate');
        if (location != null) {
          print(
              'Location: Latitude ${location.latitude}, Longitude ${location.longitude}');
        } else {
          print('Location: Not available');
        }
        print('---');
      }
    } else {
      print('No albums found.');
    }
  }

  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/');
  }
}

class Location {
  final double latitude;
  final double longitude;

  Location({required this.latitude, required this.longitude});
}
