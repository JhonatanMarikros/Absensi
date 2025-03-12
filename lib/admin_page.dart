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
      UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);
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

  Future<void> _updateStatus(
      String uid, ImageData image, String newStatus) async {
    try {
      await _firestore.collection('photos').doc(uid).update({
        'imageUrls': FieldValue.arrayRemove([image])
      });
      image['status'] = newStatus;
      await _firestore.collection('photos').doc(uid).update({
        'imageUrls': FieldValue.arrayUnion([image])
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}")),
      );
    }
  }

  Future<void> _deletePhoto(String uid, ImageData image) async {
    try {
      await _firestore.collection('photos').doc(uid).update({
        'imageUrls': FieldValue.arrayRemove([image])
      });
      await _deleteFromCloudinary(image['imageUrl']);
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
      Uri uri = Uri.parse(imageUrl);
      String fileName = uri.pathSegments.last.split('.').first;
      String publicId = "absensi/$fileName";
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
          'invalidate': 'true',
        },
      );
      if (response.statusCode != 200) {
        print("Gagal menghapus dari Cloudinary: ${response.body}");
      }
    } catch (e) {
      print("Error menghapus dari Cloudinary: $e");
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
      body: StreamBuilder(
        stream: _firestore.collection('photos').snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }
          return ListView(
            children: snapshot.data!.docs.map((doc) {
              String uid = doc.id;
              Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
              List<ImageData> imageUrls =
                  List<ImageData>.from(data['imageUrls'] ?? []);
              return imageUrls.isEmpty
                  ? SizedBox() // Tidak menampilkan Card jika tidak ada gambar
                  : Card(
                      margin: EdgeInsets.all(10),
                      child: Column(
                        children: [
                          Text('User ID: $uid',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          ...imageUrls.map((image) => Column(
                                children: [
                                  Image.network(image['imageUrl']),
                                  Text('Status: ${image['status']}'),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: [
                                      ElevatedButton(
                                        onPressed: () => _updateStatus(
                                            uid, image, "Approved"),
                                        child: Text("Approve"),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
                                        ),
                                      ),
                                      ElevatedButton(
                                        onPressed: () => _updateStatus(
                                            uid, image, "Rejected"),
                                        child: Text("Reject"),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red,
                                        ),
                                      ),
                                      IconButton(
                                        icon: Icon(Icons.delete,
                                            color: Colors.red),
                                        onPressed: () =>
                                            _deletePhoto(uid, image),
                                      ),
                                    ],
                                  ),
                                ],
                              )),
                        ],
                      ),
                    );
            }).toList(),
          );
        },
      ),
    );
  }
}
