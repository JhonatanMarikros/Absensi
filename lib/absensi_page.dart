// import 'package:flutter/material.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'masuk_page.dart';
// import 'keluar_page.dart';

// class AbsensiPage extends StatefulWidget {
//   @override
//   _AbsensiPageState createState() => _AbsensiPageState();
// }

// class _AbsensiPageState extends State<AbsensiPage> {
//   final FirebaseAuth _auth = FirebaseAuth.instance;

//   Future<void> _recordAttendance(String status, Widget nextPage) async {
//     User? user = _auth.currentUser;
//     if (user == null) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Anda harus login terlebih dahulu!')),
//       );
//       return;
//     }

//     // Pindah ke halaman sesuai status
//     Navigator.push(
//       context,
//       MaterialPageRoute(builder: (context) => nextPage),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text("Absensi Karyawan")),
//       body: Center(
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             ElevatedButton(
//               onPressed: () => _recordAttendance('Check In', MasukPage()),
//               child: Text('Masuk'),
//             ),
//             ElevatedButton(
//               onPressed: () => _recordAttendance('Check Out', KeluarPage()),
//               child: Text('Keluar'),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'masuk_page.dart';
import 'keluar_page.dart';

class AbsensiPage extends StatefulWidget {
  @override
  _AbsensiPageState createState() => _AbsensiPageState();
}

class _AbsensiPageState extends State<AbsensiPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  double totalJamKerja = 183.38; // Contoh nilai total jam kerja

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Row(
          children: [
            Text(
              "Kawan Lama Group",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Spacer(),
            CircleAvatar(
              backgroundImage: AssetImage('assets/profile.jpg'), // Ganti dengan foto user
              radius: 20,
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profil Pengguna
            Card(
              color: Colors.black,
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "RICHARD CHRISTIAN - I01276",
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          "DATA ANALYST (INTERN)",
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                      ],
                    ),
                    Spacer(),
                    CircleAvatar(
                      backgroundImage: AssetImage('assets/profile.jpg'),
                      radius: 25,
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 20),

            // Notifikasi Segera Diselesaikan
            Row(
              children: [
                Expanded(
                  child: _buildNotificationCard(
                      "Segera Diselesaikan", "Pelindungan Data Pribadi", "Periode Hingga - 31/12/99"),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: _buildNotificationCard(
                      "Segera Diselesaikan", "Pernyataan Anggota Kopkari", "Periode Hingga - 31/12/99"),
                ),
              ],
            ),
            SizedBox(height: 20),

            // Tombol Check In & Check Out
            _buildFavoriteSection(),

            SizedBox(height: 20),

            // Total Jam Kerja
            _buildTotalJamKerja(),

            SizedBox(height: 20),
          ],
        ),
      ),
      // bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  // Widget untuk Notifikasi
  Widget _buildNotificationCard(String title, String subtitle, String period) {
    return Card(
      color: Colors.grey[850],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 14)),
            SizedBox(height: 4),
            Text(subtitle, style: TextStyle(color: Colors.white, fontSize: 14)),
            SizedBox(height: 4),
            Text(period, style: TextStyle(color: Colors.white60, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  // Widget untuk Bagian Favorit (Check In & Check Out)
  Widget _buildFavoriteSection() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 3,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Favorit",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildActionButton("Check In", Colors.green, Icons.login, MasukPage()),
                SizedBox(width: 20),
                _buildActionButton("Check Out", Colors.orange, Icons.logout, KeluarPage()),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Widget untuk Tombol Check In & Check Out
  Widget _buildActionButton(String title, Color color, IconData icon, Widget nextPage) {
    return Expanded(
      child: ElevatedButton.icon(
        onPressed: () => _recordAttendance(title, nextPage),
        icon: Icon(icon, color: Colors.white),
        label: Text(title, style: TextStyle(fontSize: 16, color: Colors.white)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  // Widget untuk Total Jam Kerja
  Widget _buildTotalJamKerja() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Total Jam Kerja Saya",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 10),
        Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 150,
                height: 150,
                child: CircularProgressIndicator(
                  value: totalJamKerja / 200, // Asumsikan 200 jam max
                  backgroundColor: Colors.grey[300],
                  strokeWidth: 8,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                ),
              ),
              Text(
                "$totalJamKerja Jam",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ],
    );
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
}
