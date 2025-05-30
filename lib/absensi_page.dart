import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'masuk_page.dart';
import 'keluar_page.dart';

class AbsensiPage extends StatefulWidget {
  @override
  _AbsensiPageState createState() => _AbsensiPageState();
}

class _AbsensiPageState extends State<AbsensiPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String username = "";
  String position = "";
  String profileUrl = "";

  @override
  void initState() {
    super.initState();
    _getUserData();
  }

  Future<void> _recordAttendance(String status, Widget nextPage) async {
    User? user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Anda harus login terlebih dahulu!')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => nextPage),
    );
  }

  void _getUserData() async {
    User? user = _auth.currentUser;
    if (user != null) {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final double w = MediaQuery.of(context).size.width;
    final double h = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.indigo[900],
        title: Row(
          children: [
            Icon(Icons.access_time_filled_rounded, color: Colors.white, size: w * 0.06),
            SizedBox(width: w * 0.02),
            Expanded(
              child: Text(
                "Absensi - Sukses Bersama Mulia",
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: w * 0.045),
              ),
            ),
            CircleAvatar(
              radius: w * 0.045,
              backgroundImage: profileUrl.isNotEmpty
                  ? NetworkImage(profileUrl)
                  : AssetImage('assets/profile.png') as ImageProvider,
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(w * 0.04),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                color: Colors.indigo[900],
                elevation: 4,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: EdgeInsets.all(w * 0.04),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            username.isNotEmpty ? "Hello, $username" : "Loading...",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: w * 0.045,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: h * 0.005),
                          Text(
                            position,
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: w * 0.035,
                            ),
                          ),
                        ],
                      ),
                      Spacer(),
                      CircleAvatar(
                        radius: w * 0.06,
                        backgroundImage: profileUrl.isNotEmpty
                            ? NetworkImage(profileUrl)
                            : AssetImage('assets/profile.png') as ImageProvider,
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: h * 0.02),

              Row(
                children: [
                  Expanded(child: _buildNotificationCard("Check In", "Untuk Absensi Masuk kerja", "Selamat Bekerja", w)),
                  SizedBox(width: w * 0.03),
                  Expanded(child: _buildNotificationCard("Check Out", "Untuk Absensi Keluar Kerja", "Sampai Jumpa", w)),
                ],
              ),

              SizedBox(height: h * 0.03),
              _buildFavoriteSection(w, h),
              SizedBox(height: h * 0.02),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationCard(String title, String subtitle, String period, double w) {
    return Card(
      color: Colors.red[50],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(w * 0.03),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(
                    color: Colors.red[800],
                    fontWeight: FontWeight.bold,
                    fontSize: w * 0.04)),
            SizedBox(height: 4),
            Text(subtitle,
                style: TextStyle(color: Colors.black87, fontSize: w * 0.035)),
            SizedBox(height: 4),
            Text(period,
                style: TextStyle(color: Colors.black54, fontSize: w * 0.03)),
          ],
        ),
      ),
    );
  }

  Widget _buildFavoriteSection(double w, double h) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 3,
      child: Padding(
        padding: EdgeInsets.all(w * 0.04),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Absensi",
              style: TextStyle(fontSize: w * 0.045, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: h * 0.015),
            Row(
              children: [
                _buildActionButton("Check In", Colors.green, Icons.login, MasukPage(), w),
                SizedBox(width: w * 0.03),
                _buildActionButton("Check Out", Colors.orange, Icons.logout, KeluarPage(), w),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
      String title, Color color, IconData icon, Widget nextPage, double w) {
    return Expanded(
      child: ElevatedButton.icon(
        onPressed: () => _recordAttendance(title, nextPage),
        icon: Icon(icon, color: Colors.white, size: w * 0.05),
        label: Text(
          title,
          style: TextStyle(fontSize: w * 0.04, color: Colors.white),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: EdgeInsets.symmetric(vertical: w * 0.035),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}




  // Widget untuk Bottom Navigation Bar
  // Widget _buildBottomNavBar() {
  //   return BottomNavigationBar(
  //     type: BottomNavigationBarType.fixed,
  //     selectedItemColor: Colors.black,
  //     unselectedItemColor: Colors.grey,
  //     items: [
  //       BottomNavigationBarItem(icon: Icon(Icons.home), label: "Beranda"),
  //       BottomNavigationBarItem(icon: Icon(Icons.grid_view), label: "Menu"),
  //       BottomNavigationBarItem(icon: Icon(Icons.people), label: "Tim Saya"),
  //       BottomNavigationBarItem(
  //         icon: Stack(
  //           children: [
  //             Icon(Icons.mail),
  //             Positioned(
  //               right: 0,
  //               top: 0,
  //               child: CircleAvatar(
  //                 radius: 6,
  //                 backgroundColor: Colors.red,
  //                 child: Text("1", style: TextStyle(fontSize: 10, color: Colors.white)),
  //               ),
  //             ),
  //           ],
  //         ),
  //         label: "Kotak Masuk",
  //       ),
  //     ],
  //   );
  // }

