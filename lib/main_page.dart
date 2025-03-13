import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'home_main.dart';
import 'me.dart';
import 'panduan.dart';
import 'absensi_page.dart';
import 'registerLogin.dart';

class MainPage extends StatefulWidget {
  final String uid;
  MainPage({Key? key, required this.uid}) : super(key: key);

  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0;
  String username = "";
  String profileUrl = "";

  @override
  void initState() {
    super.initState();
    _getUserData();
  }

  void _getUserData() async {
    DocumentSnapshot userDoc =
        await FirebaseFirestore.instance.collection('users').doc(widget.uid).get();
    
    if (userDoc.exists) {
      setState(() {
        username = userDoc['username'];
        profileUrl = userDoc['profile'];
      });
    }
  }

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
        title: Row(
          children: [
            Text(
              'Sukses Bersama Mulia',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Spacer(),
            Text(
              username,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
            if (profileUrl.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: CircleAvatar(
                  backgroundImage: NetworkImage(profileUrl),
                ),
              ),
            IconButton(
              icon: Icon(Icons.logout, color: Colors.white),
              onPressed: () => _logout(context),
            ),
          ],
        ),
        backgroundColor: Colors.lightGreenAccent,
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        selectedItemColor: Color.fromARGB(255, 236, 237, 236),
        unselectedItemColor: Color.fromARGB(255, 247, 244, 244),
        backgroundColor: Color.fromARGB(255, 164, 230, 98),
        onTap: _onItemTapped,
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.account_circle_rounded), label: "ME"),
          BottomNavigationBarItem(icon: Icon(Icons.menu_book_rounded), label: "Panduan"),
          BottomNavigationBarItem(icon: Icon(Icons.check_circle_outline_rounded), label: "Absensi"),
        ],
      ),
    );
  }
}
