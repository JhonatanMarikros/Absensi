import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'camera.dart';
import 'registerLogin.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Import dotenv

class MainPage extends StatelessWidget {
  MainPage({Key? key}) : super(key: key);

  void _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => AuthScreen()),
    );
  }

  Future<void> _deletePhoto(
      BuildContext context, String docId, String imageUrl) async {
    try {
      await FirebaseFirestore.instance.collection('photos').doc(docId).delete();
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
          'invalidate': 'true',
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
        title: Text('Main Page - User'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: Column(
        children: [
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => CameraPage()),
              );
            },
            child: Text('Take Photo'),
          ),
          Expanded(
            child: StreamBuilder(
              stream:
                  FirebaseFirestore.instance.collection('photos').snapshots(),
              builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                if (!snapshot.hasData)
                  return Center(child: CircularProgressIndicator());

                return ListView(
                  children: snapshot.data!.docs.map((doc) {
                    String imageUrl = doc['imageUrl'];
                    String docId = doc.id;

                    return Card(
                      margin: EdgeInsets.all(10),
                      child: Column(
                        children: [
                          Image.network(imageUrl),
                          ListTile(
                            title: Text("Status: ${doc['status']}"),
                            subtitle: Text(
                                doc['timestamp']?.toDate().toString() ?? ''),
                            trailing: IconButton(
                              icon: Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deletePhoto(context, docId, imageUrl),
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
