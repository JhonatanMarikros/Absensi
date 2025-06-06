// main.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'admin_page.dart';
import 'main_page.dart';
import 'registerLogin.dart';
import 'package:firebase_app_check/firebase_app_check.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  await FirebaseAppCheck.instance.activate(
    // webProvider: ReCaptchaV3Provider('recaptcha-v3-site-key'),
    androidProvider: AndroidProvider.debug,
    appleProvider: AppleProvider.appAttest,
  );

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Firebase Auth CRUD',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: AuthHandler(),
    );
  }
}

class AuthHandler extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.active) {
          final user = snapshot.data;
          if (user == null) {
            return AuthScreen();
          } else {
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('users').doc(user.email).get(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Scaffold(body: Center(child: CircularProgressIndicator()));
                }
                final userData = snapshot.data!;
                final role = userData.exists ? userData['role'] : 'user';
                return role == 'admin' ? AdminHomePage() : MainPage();
              },
            );
          }
        }
        return Scaffold(body: Center(child: CircularProgressIndicator()));
      },
    );
  }
}