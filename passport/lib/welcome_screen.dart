import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: Text('Welcome to PastPort'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              'Thanks for signing up! Here’s a brief overview of PastPort. '
              'Please read and accept our Terms & Conditions.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  // Insert your actual Terms & Conditions text here
                  '1. Be excellent to each other.\n'
                  '2. Respect user data privacy.\n'
                  '3. ...',
                  style: TextStyle(fontSize: 14),
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                // Set acceptedTerms to true in Firestore
                if (userId != null) {
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(userId)
                      .set({'acceptedTerms': true}, SetOptions(merge: true));
                }
                // Navigate to Home screen
                Navigator.pushReplacementNamed(context, '/home');
              },
              child: Text('Agree and Continue'),
            ),
          ],
        ),
      ),
    );
  }
}
