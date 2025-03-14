import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'registerLogin.dart';

typedef ImageData = Map<String, dynamic>;

class AdminHomePage extends StatefulWidget {
  @override
  _AdminHomePageState createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  String? selectedUserId;

  @override
  void initState() {
    super.initState();
    dotenv.load(fileName: ".env");
  }

  void _logout() async {
    await _auth.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => AuthScreen()),
    );
  }

  Future<void> _addAdmin() async {
    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Email dan Password tidak boleh kosong!")),
      );
      return;
    }

    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'uid': userCredential.user!.uid,
        'email': email,
        'role': 'admin',
      });

      _emailController.clear();
      _passwordController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Admin berhasil ditambahkan!")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}")),
      );
    }
  }

  Future<String> _getUsername(String uid) async {
    DocumentSnapshot userDoc = await _firestore.collection('users').doc(uid).get();
    return userDoc.exists ? userDoc['username'] ?? 'Unknown' : 'Unknown';
  }

  Future<void> _deleteFromCloudinary(String imageUrl) async {
    try {
      String? cloudName = dotenv.env['CLOUDINARY_CLOUD_NAME'];
      String? apiKey = dotenv.env['CLOUDINARY_API_KEY'];
      String? apiSecret = dotenv.env['CLOUDINARY_API_SECRET'];

      if (cloudName == null || apiKey == null || apiSecret == null) {
        print("Error: Cloudinary credentials are missing.");
        return;
      }

      Uri uri = Uri.parse(imageUrl);
      String fileName = uri.pathSegments.last.split('.').first;
      String publicId = "absensi/$fileName";

      String timestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
      String stringToSign = 'public_id=$publicId&timestamp=$timestamp$apiSecret';
      String signature = sha1.convert(utf8.encode(stringToSign)).toString();

      String apiUrl = 'https://api.cloudinary.com/v1_1/$cloudName/image/destroy';

      var response = await http.post(
        Uri.parse(apiUrl),
        body: {
          'public_id': publicId,
          'api_key': apiKey,
          'timestamp': timestamp,
          'signature': signature,
          'invalidate': 'true',
        },
      );

      if (response.statusCode == 200) {
        print("✅ Berhasil menghapus dari Cloudinary.");
      } else {
        print("⚠️ Gagal menghapus dari Cloudinary: ${response.body}");
      }
    } catch (e) {
      print("❌ Error menghapus dari Cloudinary: $e");
    }
  }

  Future<void> _updateStatus(String uid, ImageData image, String newStatus) async {
    try {
      await _firestore.collection('photos').doc(uid).update({
        'imageUrls': FieldValue.arrayRemove([image])
      });

      image['status'] = newStatus;
      await _firestore.collection('photos').doc(uid).update({
        'imageUrls': FieldValue.arrayRemove([image])
      });
      await _deleteFromCloudinary(image['imageUrl']);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Foto telah diproses dan dihapus.")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}")),
      );
    }
  }

  void _toggleUserPhotos(String uid) {
    setState(() {
      selectedUserId = selectedUserId == uid ? null : uid;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Admin Management'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                TextField(controller: _emailController, decoration: InputDecoration(labelText: 'Email Admin')),
                TextField(controller: _passwordController, decoration: InputDecoration(labelText: 'Password'), obscureText: true),
                SizedBox(height: 10),
                ElevatedButton(onPressed: _addAdmin, child: Text('Tambah Admin')),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder(
              stream: _firestore.collection('photos').snapshots(),
              builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
                return ListView(
                  children: snapshot.data!.docs.map((doc) {
                    String uid = doc.id;
                    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
                    List<ImageData> imageUrls = List<ImageData>.from(data['imageUrls'] ?? []);
                    return Card(
                      margin: EdgeInsets.all(10),
                      child: Column(
                        children: [
                          ListTile(
                            leading: Icon(Icons.folder, color: Colors.amber, size: 40),
                            title: FutureBuilder<String>(
                              future: _getUsername(uid),
                              builder: (context, userSnapshot) => Text('User: ${userSnapshot.data ?? 'Loading...'}', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                            trailing: Icon(selectedUserId == uid ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down),
                            onTap: () => _toggleUserPhotos(uid),
                          ),
                          if (selectedUserId == uid) ...imageUrls.map((image) => Column(children: [Image.network(image['imageUrl']), Text('Status: ${image['status']}'),
                          Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                              children: [
                                                ElevatedButton(
                                                  onPressed: () => _updateStatus(uid, image, "Approved"),
                                                  child: Text("Approve"),
                                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                                ),
                                                ElevatedButton(
                                                  onPressed: () => _updateStatus(uid, image, "Rejected"),
                                                  child: Text("Reject"),
                                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                                ),
                                              ],
                                            ),]))
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}