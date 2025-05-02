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
    _getLatestSlipGaji();
  }

  void _getUserData() async {
    User? user = _auth.currentUser;
    if (user != null) {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        setState(() {
          username = userDoc['username'] ?? "";
          position = userDoc['position'] ?? "";
          profileUrl = userDoc['profile'] ?? "";
        });
      }
    }
  }

  void _getLatestSlipGaji() async {
    User? user = _auth.currentUser;
    if (user != null) {
      final snapshot = await FirebaseFirestore.instance
          .collection('slip_gaji')
          .doc(user.uid)
          .collection('data')
          .orderBy('tahun', descending: true)
          .orderBy('bulan', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        setState(() {
          latestSlip = snapshot.docs.first.data();
        });
      }
    }
  }

  Widget buildSlipGajiCard() {
    if (latestSlip == null) {
      return Card(
        margin: EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(Icons.receipt_long, size: 36, color: Colors.indigo[700]),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  "Slip gaji belum tersedia.",
                  style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      margin: EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Slip Gaji Terbaru",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.indigo[800],
              ),
            ),
            SizedBox(height: 8),
            Text("${latestSlip!['bulan']} ${latestSlip!['tahun']}", style: TextStyle(fontSize: 16)),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Gaji Pokok", style: TextStyle(color: Colors.grey[700])),
                Text("Rp${latestSlip!['gaji_pokok'].toString()}", style: TextStyle(fontWeight: FontWeight.w500)),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Bonus", style: TextStyle(color: Colors.grey[700])),
                Text("Rp${latestSlip!['bonus'].toString()}", style: TextStyle(fontWeight: FontWeight.w500)),
              ],
            ),
            Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Total", style: TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  "Rp${latestSlip!['total'].toString()}",
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo[900]),
                ),
              ],
            ),
            SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () {
                  // Arahkan ke halaman detail slip gaji jika ada
                },
                icon: Icon(Icons.arrow_forward, size: 18),
                label: Text("Lihat Detail"),
              ),
            ),
          ],
        ),
      ),
    );
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
            child: Text(position, style: TextStyle(fontSize: 16, color: Colors.grey[700])),
          ),
          SizedBox(height: 16),
          buildSlipGajiCard(),
          // Tambah card lainnya di bawah sini jika perlu
        ],
      ),
    );
  }
}
