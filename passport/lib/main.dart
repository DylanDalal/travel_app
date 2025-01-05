import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'login_screen.dart';
import 'signup_screen.dart'; // Create this for signup
import 'home_screen.dart'; // A simple home screen for successful login

import 'package:flutter/foundation.dart'; // For kDebugMode
import 'package:firebase_auth/firebase_auth.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  print('HELLLOOOOO');
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('Firebase initialized successfully!');
  } catch (e) {
    print('Firebase initialization error: $e');
  }
  testFirebaseConnection();



  // Use Authentication Emulator in debug mode
  if (kDebugMode) {
    await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
    print('Connected to Firebase Auth Emulator');
  }


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
      title: 'Test Login',
      initialRoute: '/',
      routes: {
        '/': (context) => LoginScreen(),
        '/signup': (context) => SignupScreen(), // Create this screen for signup
        '/home': (context) => HomeScreen(), // A basic home screen
      },
    );
  }
}
