import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'registerLogin.dart';

class AdminHomePage extends StatefulWidget {
  @override
  _AdminHomePageState createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    dotenv.load(fileName: ".env"); // Load .env variables
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
      UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);

      await _firestore.collection('users').doc(userCredential.user!.email).set({
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

  void _deleteAdmin(String email) async {
    try {
      await _firestore.collection('users').doc(email).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Admin $email berhasil dihapus!")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}")),
      );
    }
  }

  void _updateStatus(String docId, String newStatus) async {
    try {
      await _firestore.collection('photos').doc(docId).update({
        'status': newStatus,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Status berhasil diperbarui!")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}")),
      );
    }
  }

  Future<void> _deletePhoto(String docId, String imageUrl) async {
    try {
      await _firestore.collection('photos').doc(docId).delete();
      await _deleteFromCloudinary(imageUrl);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Foto berhasil dihapus!")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}")),
      );
    }
  }

  Future<void> _deleteFromCloudinary(String imageUrl) async {
    try {
      String cloudName = dotenv.env['CLOUDINARY_CLOUD_NAME']!;
      String apiKey = dotenv.env['CLOUDINARY_API_KEY']!;
      String apiSecret = dotenv.env['CLOUDINARY_API_SECRET']!;

      // Ekstrak `public_id` dari URL Cloudinary
      Uri uri = Uri.parse(imageUrl);
      String fileName = uri.pathSegments.last.split('.').first;
      String publicId =
          "absensi/$fileName"; // Sesuaikan dengan folder Cloudinary

      String timestamp =
          (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
      String stringToSign =
          'public_id=$publicId&timestamp=$timestamp$apiSecret';
      String signature = sha1.convert(utf8.encode(stringToSign)).toString();

      String apiUrl =
          'https://api.cloudinary.com/v1_1/$cloudName/image/destroy';

      var response = await http.post(
        Uri.parse(apiUrl),
        body: {
          'public_id': publicId,
          'api_key': apiKey,
          'timestamp': timestamp,
          'signature': signature,
          'invalidate': 'true', // Menyegarkan cache Cloudinary
        },
      );

      if (response.statusCode == 200) {
        print("Foto berhasil dihapus dari Cloudinary");
      } else {
        print("Gagal menghapus foto dari Cloudinary: ${response.body}");
      }
    } catch (e) {
      print("Error saat menghapus foto dari Cloudinary: $e");
    }
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
          // Form Tambah Admin
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(labelText: 'Email Admin'),
                ),
                TextField(
                  controller: _passwordController,
                  decoration: InputDecoration(labelText: 'Password'),
                  obscureText: true,
                ),
                SizedBox(height: 10),
                ElevatedButton(
                  onPressed: _addAdmin,
                  child: Text('Tambah Admin'),
                ),
              ],
            ),
          ),

          // Tampilkan daftar admin
          Expanded(
            child: StreamBuilder(
              stream: _firestore
                  .collection('users')
                  .where('role', isEqualTo: 'admin')
                  .snapshots(),
              builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                if (!snapshot.hasData)
                  return Center(child: CircularProgressIndicator());

                return ListView(
                  children: snapshot.data!.docs.map((doc) {
                    String email = doc.id;
                    return ListTile(
                      title: Text(email),
                      trailing: IconButton(
                        icon: Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteAdmin(email),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
          Expanded(
            child: StreamBuilder(
              stream: _firestore.collection('photos').snapshots(),
              builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                if (!snapshot.hasData)
                  return Center(child: CircularProgressIndicator());

                return ListView(
                  children: snapshot.data!.docs.map((doc) {
                    String imageUrl =
                        doc['imageUrl']; // Pastikan field Firestore benar
                    String docId = doc.id;
                    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
                    String status = data.containsKey('status') ? data['status'] : "Pending";



                    return Card(
                      margin: EdgeInsets.all(10),
                      child: Column(
                        children: [
                          Image.network(
                              imageUrl), // Menampilkan gambar dari Cloudinary
                          Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Column(
                              children: [
                                Text('Status: $status'),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    ElevatedButton(
                                      onPressed: () =>
                                          _updateStatus(docId, "Approved"),
                                      child: Text("Approve"),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                      ),
                                    ),
                                    ElevatedButton(
                                      onPressed: () =>
                                          _updateStatus(docId, "Rejected"),
                                      child: Text("Reject"),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                      ),
                                    ),
                                    IconButton(
                                      icon:
                                          Icon(Icons.delete, color: Colors.red),
                                      onPressed: () =>
                                          _deletePhoto(docId, imageUrl),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
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
