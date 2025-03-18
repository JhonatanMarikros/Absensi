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
  double logoSize = 150.0;
  double logoTopPadding = 5.0;
  double profileTopPadding = 100.0;

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
    AbsensiPage(),
    PanduanPage(),
    MePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(150.0), // Menambah tinggi AppBar
        child: AppBar(
          backgroundColor: Color.fromARGB(255, 52, 75, 52),
          centerTitle: true,
          flexibleSpace: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 10.0),
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: EdgeInsets.only(top: logoTopPadding),
                    child: Image.asset('assets/SBMNEW.png', height: logoSize),
                  ),
                ),
                if (profileUrl.isNotEmpty)
                  Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: EdgeInsets.only(top: profileTopPadding),
                      child: CircleAvatar(
                        radius: 50,
                        backgroundImage: NetworkImage(profileUrl),
                        backgroundColor: Color.fromARGB(255, 181, 161, 106),
                      ),
                    ),
                  ),
                Align(
                  alignment: Alignment.bottomRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 10.0, bottom: 70.0),
                    child: IconButton(
                      icon: Icon(Icons.logout, color: const Color.fromARGB(255, 159, 16, 16)),
                      onPressed: () => _logout(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: _pages[_selectedIndex], 
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Colors.green[900],
        unselectedItemColor: Colors.grey,
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.check_circle), label: "Absensi"),
          BottomNavigationBarItem(icon: Icon(Icons.menu_book), label: "Panduan"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ],
      ),
    );
  }
}
