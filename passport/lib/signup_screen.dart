// lib/signup_screen.dart

import 'package:flutter/material.dart';
import '../user_data/data_operations.dart'; // Import DataSaver
import 'post_signup_options_screen.dart'; // Import the new screen

class SignupScreen extends StatefulWidget {
  SignupScreen({Key? key}) : super(key: key);

  @override
  _SignupScreenState createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool _isLoading = false;

  void _signUp() async {
    setState(() {
      _isLoading = true;
    });

    await DataSaver.signUp(
      email: emailController.text,
      password: passwordController.text,
      context: context,
    );

    setState(() {
      _isLoading = false;
    });

    // Navigate to PostSignUpOptionsScreen if sign-up is successful
    // Assuming signUp method navigates on success
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign Up')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Email TextField
            TextField(
              controller: emailController,
              decoration: InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            SizedBox(height: 16),
            // Password TextField
            TextField(
              controller: passwordController,
              decoration: InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            SizedBox(height: 16),
            // Sign Up Button
            _isLoading
                ? CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _signUp,
                    child: Text('Sign Up'),
                  ),
          ],
        ),
      ),
    );
  }
}
