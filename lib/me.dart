import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

class MePage extends StatefulWidget {
  @override
  _MePageState createState() => _MePageState();
}

class _MePageState extends State<MePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final TextEditingController _usernameController = TextEditingController();

  String email = "";
  String profileImage = "";
  String uid = "";
  bool isEditing = false;

  File? _selectedImage;

 final String cloudinaryUrl =
    "https://api.cloudinary.com/v1_1/${dotenv.env['CLOUDINARY_CLOUD_NAME']}/image/upload";
  final String uploadPreset = "absensi";

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() async {
    final user = _auth.currentUser;
    if (user != null) {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        setState(() {
          uid = user.uid;
          _usernameController.text = userDoc['username'] ?? '';
          email = userDoc['email'] ?? '';
          profileImage = userDoc['profile'] ?? '';
        });
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await ImagePicker().pickImage(source: source);
    if (pickedFile != null) {
      final cropped = await _cropImage(File(pickedFile.path));
      if (cropped != null) {
        setState(() => _selectedImage = cropped);
      }
    }
  }

  Future<File?> _cropImage(File file) async {
    final croppedFile = await ImageCropper().cropImage(
      sourcePath: file.path,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Image',
          toolbarColor: Colors.blue,
          toolbarWidgetColor: Colors.white,
        ),
        IOSUiSettings(minimumAspectRatio: 1.0),
      ],
    );
    return croppedFile != null ? File(croppedFile.path) : null;
  }

  Future<void> _deleteFromCloudinary(String publicId) async {
    final cloudName = dotenv.env['CLOUDINARY_CLOUD_NAME']!;
    final apiKey = dotenv.env['CLOUDINARY_API_KEY']!;
    final apiSecret = dotenv.env['CLOUDINARY_API_SECRET']!;

    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final signatureBase = "public_id=$publicId&timestamp=$timestamp$apiSecret";
    final signature = sha1.convert(utf8.encode(signatureBase)).toString();

    final url = "https://api.cloudinary.com/v1_1/$cloudName/image/destroy";

    final response = await http.post(
      Uri.parse(url),
      body: {
        "public_id": publicId,
        "api_key": apiKey,
        "timestamp": "$timestamp",
        "signature": signature,
      },
    );

    if (response.statusCode != 200) {
      print("Cloudinary deletion failed: ${response.body}");
    }
  }

  Future<void> _uploadToCloudinary() async {
    if (_selectedImage == null) return;

    _showLoadingDialog();

    try {
      // Ambil public_id lama jika ada
      final userDoc = await _firestore.collection('users').doc(uid).get();
      final oldPublicId = userDoc.data()?['public_id'];

      // Upload baru
      final request = http.MultipartRequest('POST', Uri.parse(cloudinaryUrl))
        ..fields['upload_preset'] = uploadPreset
        ..files.add(
            await http.MultipartFile.fromPath('file', _selectedImage!.path));

      final response = await request.send();
      final jsonResponse = json.decode(await response.stream.bytesToString());
      final url = jsonResponse['secure_url'];
      final publicId = jsonResponse['public_id'];

      if (url != null && publicId != null) {
        // Hapus gambar lama jika ada
        if (oldPublicId != null && oldPublicId.isNotEmpty) {
          await _deleteFromCloudinary(oldPublicId);
        }

        // Simpan ke Firestore
        await _firestore.collection('users').doc(uid).update({
          'profile': url,
          'public_id': publicId,
        });

        setState(() {
          profileImage = url;
          _selectedImage = null;
        });
      }
    } catch (e) {
      print("Upload error: $e");
    } finally {
      Navigator.pop(context);
    }
  }

  void _updateUsername() async {
    if (_usernameController.text.isEmpty) return;

    _showLoadingDialog();
    await _firestore.collection('users').doc(uid).update({
      'username': _usernameController.text.trim(),
    });
    setState(() => isEditing = false);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text("Username updated successfully!"),
    ));
  }

  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text("Memproses..."),
          ],
        ),
      ),
    );
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      builder: (_) => Wrap(
        children: [
          ListTile(
            leading: Icon(Icons.camera_alt),
            title: Text("Take Photo"),
            onTap: () {
              Navigator.pop(context);
              _pickImage(ImageSource.camera);
            },
          ),
          ListTile(
            leading: Icon(Icons.photo),
            title: Text("Choose from Gallery"),
            onTap: () {
              Navigator.pop(context);
              _pickImage(ImageSource.gallery);
            },
          ),
        ],
      ),
    );
  }

  void _showImagePopup(String imageUrl) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.all(10),
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: InteractiveViewer(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                image: DecorationImage(
                  image: NetworkImage(imageUrl),
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAttendanceBox(String label, String value, Color color) {
    return Container(
      width: 100,
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  fontSize: 18, color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Profil - Sukses Bersama Mulia"),
        backgroundColor: Colors.indigo[900],
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: CircleAvatar(
              backgroundImage: profileImage.isNotEmpty
                  ? NetworkImage(profileImage)
                  : AssetImage('assets/profile.png') as ImageProvider,
            ),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          Center(
            child: GestureDetector(
              onTap: _showImagePickerOptions,
              child: CircleAvatar(
                radius: 50,
                backgroundImage: _selectedImage != null
                    ? FileImage(_selectedImage!)
                    : profileImage.isNotEmpty
                        ? NetworkImage(profileImage)
                        : AssetImage("assets/profile.png") as ImageProvider,
              ),
            ),
          ),
          if (_selectedImage != null)
            TextButton.icon(
              onPressed: _uploadToCloudinary,
              icon: Icon(Icons.upload),
              label: Text("Upload"),
            ),
          SizedBox(height: 20),
          Text("Email: $email", style: TextStyle(fontSize: 16)),
          SizedBox(height: 10),
          TextField(
            controller: _usernameController,
            enabled: isEditing,
            decoration: InputDecoration(labelText: 'Username'),
          ),
          SizedBox(height: 12),
          ElevatedButton(
            onPressed: isEditing
                ? _updateUsername
                : () => setState(() => isEditing = true),
            child: Text(isEditing ? "Save" : "Edit Username"),
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.indigo[900]),
          ),
          SizedBox(height: 24),
          Center(
            child: Text(
              "Statistik",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          SizedBox(height: 8),
          if (uid.isNotEmpty)
            StreamBuilder<DocumentSnapshot>(
              stream: _firestore.collection('photos').doc(uid).snapshots(),
              builder: (_, snapshot) {
                if (!snapshot.hasData || !snapshot.data!.exists) {
                  return Text("Data tidak tersedia");
                }
                final data = snapshot.data!.data() as Map<String, dynamic>?;
                final stats =
                    data?['statistics'] as Map<String, dynamic>? ?? {};

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildAttendanceBox(
                        "Hadir", "${stats['hadir'] ?? 0}", Colors.green),
                    _buildAttendanceBox(
                        "Telat", "${stats['totalTelat'] ?? 0}", Colors.red),
                    _buildAttendanceBox("Waktu",
                        "${stats['waktuTelat'] ?? 0} mnt", Colors.orange),
                  ],
                );
              },
            ),
          SizedBox(height: 24),
          Center(
            child: Text(
              "Riwayat Foto",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          if (uid.isNotEmpty)
            StreamBuilder<DocumentSnapshot>(
              stream: _firestore.collection('photos').doc(uid).snapshots(),
              builder: (_, snapshot) {
                if (!snapshot.hasData || !snapshot.data!.exists) {
                  return Text("Tidak ada foto tersedia");
                }

                final data = snapshot.data!.data() as Map<String, dynamic>?;
                final imageUrls =
                    List<Map<String, dynamic>>.from(data?['imageUrls'] ?? []);

                return Column(
                  children: imageUrls.map((image) {
                    final timestamp = image['timestamp']?.toDate();
                    final formatted = timestamp != null
                        ? "${timestamp.day}/${timestamp.month}/${timestamp.year} ${timestamp.hour}:${timestamp.minute}"
                        : "Tidak diketahui";

                    final location = image['location'] ?? {};
                    final address = location['address'] ?? 'Tidak tersedia';
                    final radius = location['radius'] ?? 'Tidak diketahui';

                    return Card(
                      margin: EdgeInsets.symmetric(vertical: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GestureDetector(
                              onTap: () => _showImagePopup(image['imageUrl']),
                              child: AspectRatio(
                                aspectRatio: 4 / 3,
                                child: Image.network(image['imageUrl'],
                                    fit: BoxFit.cover),
                              ),
                            ),
                            SizedBox(height: 8),
                            Text("Status: ${image['status']}"),
                            Text(
                                "Check: ${image['statusCheckInCheckOut'] ?? 'Tidak diketahui'}"),
                            Text("Waktu: $formatted"),
                            Text("Lokasi: $address"),
                            Text("Radius: $radius"),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
        ],
      ),
    );
  }
}
