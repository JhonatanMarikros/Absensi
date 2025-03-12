import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'admin_page.dart';
import 'main_page.dart';

class AuthScreen extends StatefulWidget {
  @override
  _AuthScreenState createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool isLogin = true;

  void _authenticate() async {
    try {
      UserCredential userCredential;
      if (isLogin) {
        // LOGIN
        userCredential = await _auth.signInWithEmailAndPassword(
          email: _emailController.text,
          password: _passwordController.text,
        );
      } else {
        // REGISTER
        userCredential = await _auth.createUserWithEmailAndPassword(
          email: _emailController.text,
          password: _passwordController.text,
        );

        // Simpan data pengguna di Firestore dengan UID sebagai primary key
        await _firestore.collection('users').doc(userCredential.user!.uid).set({
          'uid': userCredential.user!.uid, // Menyimpan UID sebagai field
          'email': _emailController.text,
          'username': _usernameController.text,
          'profile': "", // Kosong dulu, bisa diupload nanti
          'role': 'user',
        });
      }

      // Ambil role user dari Firestore
      DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();
      String role = userDoc.exists ? userDoc['role'] : 'user';

      // Arahkan berdasarkan role
      if (role == 'admin') {
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (context) => AdminHomePage()));
      } else {
        Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (context) => MainPage(uid: userCredential.user!.uid)));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(isLogin ? 'Login' : 'Register')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!isLogin)
              TextField(
                controller: _usernameController,
                decoration: InputDecoration(labelText: 'Username'),
              ),
            TextField(
              controller: _emailController,
              decoration: InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _authenticate,
              child: Text(isLogin ? 'Login' : 'Register'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  isLogin = !isLogin;
                });
              },
              child: Text(isLogin
                  ? 'Create an account'
                  : 'Already have an account? Login'),
            ),
          ],
        ),
      ),
    );
  }
}
