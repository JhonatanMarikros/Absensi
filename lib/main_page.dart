import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'home_main.dart';
import 'me.dart';
import 'panduan.dart';
import 'absensi_page.dart';
import 'registerLogin.dart';

class MainPage extends StatefulWidget {
  MainPage({Key? key}) : super(key: key);

  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => AuthScreen()),
    );
  }

  final List<Widget> _pages = [
    HomeMain(),
    MePage(),
    PanduanPage(),
    AbsensiPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Main Page - User'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: _pages[_selectedIndex], // Menampilkan halaman yang sesuai
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: "Home",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: "ME",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book), // Ikon Panduan
            label: "Panduan",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.check_circle), // Ikon Absensi
            label: "Absensi",
          ),
        ],
      ),
    );
  }
}
