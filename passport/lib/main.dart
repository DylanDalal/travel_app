// lib/main.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'login_screen.dart';
import 'signup_screen.dart';
import 'home_screen.dart';
import 'post_signup_options_screen.dart';
import 'automatically_load_trips_screen.dart';
import 'welcome_screen.dart'; // Ensure this exists

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('Firebase initialized successfully!');
  } catch (e) {
    print('Firebase initialization error: $e');
  }
  testFirebaseConnection();

  runApp(MyApp());
}

void testFirebaseConnection() async {
  try {
    final auth = FirebaseAuth.instance;
    print('Firebase Auth initialized: ${auth.app.name}');
  } catch (e) {
    print('Error: $e');
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Passport App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => LoginScreen(),
        '/signup': (context) => SignupScreen(),
        '/welcome': (context) => PostSignUpOptionsScreen(),
        '/automatically_load_trips': (context) => AutomaticallyLoadTripsScreen(),
        '/home': (context) => HomeScreen(),
      },
    );
  }
}
