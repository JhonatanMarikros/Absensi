import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class MePage extends StatefulWidget {
  @override
  _MePageState createState() => _MePageState();
}

class _MePageState extends State<MePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  TextEditingController _usernameController = TextEditingController();
  String email = "";
  String profileImage = "";
  bool isEditing = false;
  String uid = "";

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

void _loadUserData() async {
  User? user = _auth.currentUser;
  if (user != null) {
    print("User UID: ${user.uid}"); // Debugging
    DocumentSnapshot userDoc = await _firestore.collection('users').doc(user.uid).get();
    
    if (userDoc.exists) {
      setState(() {
        uid = user.uid;
        _usernameController.text = userDoc['username'];
        email = userDoc['email'];
        profileImage = userDoc['profile'] ?? "";
      });
    }
  } else {
    print("User belum login.");
  }
}


  void _updateUsername() async {
    User? user = _auth.currentUser;
    if (user != null) {
      await _firestore.collection('users').doc(user.uid).update({
        'username': _usernameController.text,
      });
      setState(() {
        isEditing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Username updated successfully!")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Profile")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 50,
              backgroundImage: profileImage.isNotEmpty
                  ? NetworkImage(profileImage)
                  : AssetImage("assets/default_profile.png") as ImageProvider,
            ),
            SizedBox(height: 20),
            Text("Email: $email", style: TextStyle(fontSize: 16)),
            SizedBox(height: 10),
            TextField(
              controller: _usernameController,
              enabled: isEditing,
              decoration: InputDecoration(labelText: 'Username'),
            ),
            SizedBox(height: 20),
            isEditing
                ? ElevatedButton(
                    onPressed: _updateUsername,
                    child: Text("Save"),
                  )
                : ElevatedButton(
                    onPressed: () {
                      setState(() {
                        isEditing = true;
                      });
                    },
                    child: Text("Edit Username"),
                  ),
            SizedBox(height: 20),

            /// Menampilkan foto berdasarkan UID pengguna
            Expanded(
  child: uid.isNotEmpty
      ? StreamBuilder<DocumentSnapshot>(
          stream: _firestore.collection('photos').doc(uid).snapshots(),
          builder: (context, AsyncSnapshot<DocumentSnapshot> snapshot) {
            if (!snapshot.hasData || !snapshot.data!.exists) {
              return Center(child: Text("Tidak ada foto yang tersedia"));
            }

            Map<String, dynamic>? data = snapshot.data!.data() as Map<String, dynamic>?;

            if (data == null || !data.containsKey('imageUrls')) {
              return Center(child: Text("Tidak ada foto yang tersedia"));
            }

            List<Map<String, dynamic>> imageUrls = List<Map<String, dynamic>>.from(data['imageUrls']);

            return ListView(
              children: imageUrls.map((image) {
                return Card(
                  margin: EdgeInsets.all(10),
                  child: Column(
                    children: [
                      Image.network(image['imageUrl']),
                      SizedBox(height: 5),
                      Text(
                        'Status: ${image['status']}',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        )
      : Center(child: CircularProgressIndicator()), // Tambahkan indikator loading
),

          ],
        ),
      ),
    );
  }
}