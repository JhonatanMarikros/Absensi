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

  Future<void> _recordAttendance(String status, Widget nextPage) async {
    User? user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Anda harus login terlebih dahulu!')),
      );
      return;
    }

    // Pindah ke halaman sesuai status
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => nextPage),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Absensi Karyawan")),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed: () => _recordAttendance('Check In', MasukPage()),
              child: Text('Masuk'),
            ),
            ElevatedButton(
              onPressed: () => _recordAttendance('Check Out', KeluarPage()),
              child: Text('Keluar'),
            ),
          ],
        ),
      ),
    );
  }
}
