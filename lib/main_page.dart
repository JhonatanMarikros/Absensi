import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'home_main.dart';
import 'me.dart';
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
  String position = "";
  String profileUrl = "";

  final List<Widget> _pages = [
    HomeMain(),
    AbsensiPage(),
    MePage(),
  ];

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

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(screenHeight * 0.13),
        child: AppBar(
          backgroundColor: Colors.black,
          flexibleSpace: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: screenWidth * 0.04,
              vertical: screenHeight * 0.015,
            ),
            child: StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(widget.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }

                var userDoc = snapshot.data!;
                username = userDoc['username'] ?? 'Loading...';
                position = userDoc['position'] ?? '';
                profileUrl = userDoc['profile'] ?? '';

                return Stack(
                  children: [
                    Align(
                      alignment: Alignment.topLeft,
                      child: Padding(
                        padding: EdgeInsets.only(top: screenHeight * 0.015),
                        child: Image.asset(
                          'assets/SBMOLD.png',
                          height: screenHeight * 0.18,
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: EdgeInsets.only(bottom: screenHeight * 0.02),
                        child: Text(
                          "$username - $position",
                          style: TextStyle(
                            fontSize: screenWidth * 0.045,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Padding(
                        padding: EdgeInsets.only(bottom: screenHeight * 0.015),
                        child: IconButton(
                          icon: const Icon(Icons.logout,
                              color: Color.fromARGB(255, 159, 16, 16)),
                          onPressed: () => _logout(context),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
      body: SafeArea(child: _pages[_selectedIndex]),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.indigo[700],
        onPressed: () {
          setState(() {
            _selectedIndex = 1;
          });
        },
        child: Icon(Icons.calendar_today, size: screenWidth * 0.07),
      ),
      bottomNavigationBar: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        child: BottomAppBar(
          color: Colors.indigo[900],
          shape: const CircularNotchedRectangle(),
          notchMargin: 8.0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              IconButton(
                icon: Icon(Icons.home,
                    size: screenWidth * 0.07,
                    color: _selectedIndex == 0 ? Colors.white : Colors.grey),
                onPressed: () {
                  setState(() {
                    _selectedIndex = 0;
                  });
                },
              ),
              SizedBox(width: screenWidth * 0.1), // Space for FAB
              IconButton(
                icon: Icon(Icons.person,
                    size: screenWidth * 0.07,
                    color: _selectedIndex == 2 ? Colors.white : Colors.grey),
                onPressed: () {
                  setState(() {
                    _selectedIndex = 2;
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
