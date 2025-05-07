// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/material.dart';
// import 'home_main.dart';
// import 'me.dart';
// import 'panduan.dart';
// import 'absensi_page.dart';
// import 'registerLogin.dart';

// class MainPage extends StatefulWidget {
//   final String uid;
//   MainPage({Key? key, required this.uid}) : super(key: key);

//   @override
//   _MainPageState createState() => _MainPageState();
// }

// class _MainPageState extends State<MainPage> {
//   int _selectedIndex = 0;
//   String username = "";
//   String profileUrl = "";

//   @override
//   void initState() {
//     super.initState();
//     _getUserData();
//   }

//   void _getUserData() async {
//     DocumentSnapshot userDoc =
//         await FirebaseFirestore.instance.collection('users').doc(widget.uid).get();

//     if (userDoc.exists) {
//       setState(() {
//         username = userDoc['username'];
//         profileUrl = userDoc['profile'];
//       });
//     }
//   }

//   void _onItemTapped(int index) {
//     setState(() {
//       _selectedIndex = index;
//     });
//   }

//   void _logout(BuildContext context) async {
//     await FirebaseAuth.instance.signOut();
//     Navigator.pushReplacement(
//       context,
//       MaterialPageRoute(builder: (context) => AuthScreen()),
//     );
//   }

//   final List<Widget> _pages = [
//     HomeMain(),
//     PanduanPage(),
//     MePage(),
//     AbsensiPage(),
//   ];

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Main Page - $username', style: TextStyle(color: Colors.white)),
//         backgroundColor: Color.fromARGB(255, 245, 247, 245),
//         leading: Padding(
//           padding: const EdgeInsets.all(1),
//           child: Image.asset('assets/SBMNEW.png'),
//         ),
//         actions: [
//           if (profileUrl.isNotEmpty)
//             CircleAvatar(
//               backgroundImage: NetworkImage(profileUrl),
//             ),
//           IconButton(
//             icon: Icon(Icons.logout, color: Colors.white),
//             onPressed: () => _logout(context),
//           ),
//         ],
//       ),
//       body: _pages[_selectedIndex],
//       bottomNavigationBar: BottomNavigationBar(
//         type: BottomNavigationBarType.fixed,
//         currentIndex: _selectedIndex,
//         onTap: _onItemTapped,
//         selectedItemColor: Colors.green[900],
//         unselectedItemColor: Colors.grey,
//         items: [
//           BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
//           BottomNavigationBarItem(icon: Icon(Icons.person), label: "ME"),
//           BottomNavigationBarItem(icon: Icon(Icons.menu_book), label: "Panduan"),
//           BottomNavigationBarItem(icon: Icon(Icons.check_circle), label: "Absensi"),
//         ],
//       ),
//     );
//   }
// }

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
  double logoSize = 150.0;
  double logoTopPadding = 5.0;
  double profileTopPadding = 100.0;

  @override
  void initState() {
    super.initState();
    _getUserData();
  }

  void _getUserData() async {
    DocumentSnapshot userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.uid)
        .get();

    if (userDoc.exists) {
      setState(() {
        username = userDoc['username'];
        position = userDoc['position'] ?? ""; // Ambil position jika tersedia
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
    AbsensiPage(),
    MePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(90.0),
        child: AppBar(
          backgroundColor: const Color.fromARGB(255, 0, 0, 0),
          flexibleSpace: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Stack(
              children: [
                // Logo perusahaan di kiri atas
                Align(
                  alignment: Alignment.topLeft,
                  child: Padding(padding: const EdgeInsets.only(top: 15.0),
                  
                  child: Image.asset(
                    'assets/SBMNEW.png',
                    height: 300,
                  ),
                ),
            ),
                // Foto profil di kanan atas
                // if (profileUrl.isNotEmpty)
                //   Align(
                //     alignment: Alignment.topRight,
                //     child: CircleAvatar(
                //       radius: 35,
                //       backgroundImage: NetworkImage(profileUrl),
                //       backgroundColor: const Color.fromARGB(255, 181, 161, 106),
                //     ),
                //   ),

                // Username dan posisi di tengah bawah
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 25.0),
                    child: Text(
                      username.isNotEmpty
                          ? "$username - $position"
                          : "Loading...",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),

                // Tombol logout di kanan bawah
                Align(
                  alignment: Alignment.bottomRight,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 10.0),
                  child: IconButton(
                    icon: const Icon(Icons.logout,
                        color: Color.fromARGB(255, 159, 16, 16)),
                    onPressed: () => _logout(context),
                  ),
                ),
                ),
              ],
            ),
          ),
        ),
      ),

      // Body & BottomNavigationBar tetap
      body: _pages[_selectedIndex],
    floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    floatingActionButton: FloatingActionButton(
      backgroundColor: Colors.indigo[700],
      onPressed: () {
        setState(() {
          _selectedIndex = 1; // pindah ke Absensi
        });
      },
      child: Icon(Icons.check_circle, size: 30), // Ganti dengan icon absensi/QRIS
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
          icon: Icon(Icons.home, color: _selectedIndex == 0 ? Colors.white : Colors.grey),
          onPressed: () {
            setState(() {
              _selectedIndex = 0;
            });
          },
        ),
        SizedBox(width: 40), // ruang untuk FAB
        IconButton(
          icon: Icon(Icons.person, color: _selectedIndex == 2 ? Colors.white : Colors.grey),
          onPressed: () {
            setState(() {
              _selectedIndex = 2;
            });
          },
        ),
      
          SizedBox(width: 40), // ruang untuk FAB
          IconButton(
            icon: Icon(Icons.person, color: _selectedIndex == 2 ? Colors.white : Colors.grey),
            onPressed: () {
              setState(() {
                _selectedIndex = 2;
              });
            },
          ),
        ],
      ),
    ),
  ));
 }
}