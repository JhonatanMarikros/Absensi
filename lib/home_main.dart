import 'package:absensi/salaryUser.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HomeMain extends StatefulWidget {
  @override
  _HomeMainState createState() => _HomeMainState();
}

class _HomeMainState extends State<HomeMain> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String username = "";
  String position = "";
  String profileUrl = "";
  Map<String, dynamic>? latestSlip;

  @override
  void initState() {
    super.initState();
    _getUserData();
  }

  void _getUserData() async {
    User? user = _auth.currentUser;
    if (user != null) {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        setState(() {
          username = userDoc['username'] ?? "";
          position = userDoc['position'] ?? "";
          profileUrl = userDoc['profile'] ?? "";
        });
      }

      // Ambil slip gaji terbaru
      final slipQuery = await FirebaseFirestore.instance
          .collection('salary')
          .where('uid', isEqualTo: user.uid)
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (slipQuery.docs.isNotEmpty) {
        setState(() {
          latestSlip = slipQuery.docs.first.data();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.indigo[900],
        title: Row(
          children: [
            Icon(Icons.home, color: Colors.white),
            SizedBox(width: 8),
            Text("Home - Sukses Bersama Mulia"),
            Spacer(),
            CircleAvatar(
              backgroundImage: profileUrl.isNotEmpty
                  ? NetworkImage(profileUrl)
                  : AssetImage('assets/profile.jpg') as ImageProvider,
              radius: 20,
            ),
          ],
        ),
      ),
      body: ListView(
        children: [
          SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              "Selamat datang, $username",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(position,
                style: TextStyle(fontSize: 16, color: Colors.grey[700])),
          ),
          SizedBox(height: 16),

          // Tambahkan tombol untuk membuka halaman Slip Gaji User
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SalaryUserPage(
                        uid: FirebaseAuth.instance.currentUser!.uid),
                  ),
                );
              },
              child:
                  Text("Lihat Slip Gaji", style: TextStyle(fontSize: 16)),
              style: ElevatedButton.styleFrom(
                primary: Colors.indigo[900], // Warna tombol
                padding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
