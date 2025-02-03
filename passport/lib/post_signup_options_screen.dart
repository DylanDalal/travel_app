// lib/post_signup_options_screen.dart

import 'package:flutter/material.dart';
import 'automatically_load_trips_screen.dart';
import 'home_screen.dart'; // Ensure correct path

class PostSignUpOptionsScreen extends StatelessWidget {
  const PostSignUpOptionsScreen({Key? key}) : super(key: key);

  void _navigateToAutomaticallyLoadTrips(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => AutomaticallyLoadTripsScreen()),
    );
  }

  void _navigateToManuallyLoadTrips(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Welcome to Passport!'),
        automaticallyImplyLeading: false, // Prevent back navigation
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Automatically Load Trips Option
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Passport will automatically load your past trips based on location data attached to your photos. None of these photos are ever visible to us or stored in our database—we only access the location metadata. You may also manually select and limit the pictures that Passport creates trips from by allowing selective photo access.",
                      style: TextStyle(fontSize: 16),
                    ),
                    SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => _navigateToAutomaticallyLoadTrips(context),
                      child: Text('Automatically Load Trips'),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 24),
            // Manually Load Trips Option
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "To manually create trips and use Passport without granting access to photos, you can click below.",
                      style: TextStyle(fontSize: 16),
                    ),
                    SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => _navigateToManuallyLoadTrips(context),
                      child: Text('Manually Load Trips'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
