import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';

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
  File? _selectedImage;
  final String cloudinaryUrl = "https://api.cloudinary.com/v1_1/dxmczui47/image/upload";
  final String uploadPreset = "absensi";

  // Variables to store attendance data
  int hadir = 0;
  int totalTelat = 0;
  int waktuTelat = 0;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() async {
    User? user = _auth.currentUser;
    if (user != null) {
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        setState(() {
          uid = user.uid;
          _usernameController.text = userDoc['username'];
          email = userDoc['email'];
          profileImage = userDoc['profile'] ?? "";
        });

        // Fetch attendance data
        _fetchAttendanceData();
      }
    }
  }

  void _fetchAttendanceData() async {
    DocumentSnapshot userDoc = await _firestore.collection('photos').doc(uid).get();
    if (userDoc.exists) {
      setState(() {
        hadir = userDoc['hadir'] ?? 0;
        totalTelat = userDoc['totalTelat'] ?? 0;
        waktuTelat = userDoc['waktuTelat'] ?? 0;
      });
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await ImagePicker().pickImage(source: source);
    if (pickedFile != null) {
      File? croppedFile = await _cropImage(File(pickedFile.path));
      if (croppedFile != null) {
        setState(() {
          _selectedImage = croppedFile;
        });
      }
    }
  }

  Future<File?> _cropImage(File imageFile) async {
    CroppedFile? croppedFile = await ImageCropper().cropImage(
      sourcePath: imageFile.path,
      aspectRatioPresets: [
        CropAspectRatioPreset.square,
        CropAspectRatioPreset.ratio3x2,
        CropAspectRatioPreset.original,
        CropAspectRatioPreset.ratio4x3,
        CropAspectRatioPreset.ratio16x9,
      ],
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Image',
          toolbarColor: Colors.blue,
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.original,
          lockAspectRatio: false,
        ),
        IOSUiSettings(
          minimumAspectRatio: 1.0,
        ),
      ],
    );
    return croppedFile != null ? File(croppedFile.path) : null;
  }

  Future<void> _uploadToCloudinary() async {
    if (_selectedImage == null) return;
    try {
      var request = http.MultipartRequest('POST', Uri.parse(cloudinaryUrl));
      request.fields['upload_preset'] = uploadPreset;
      request.files.add(await http.MultipartFile.fromPath('file', _selectedImage!.path));

      var response = await request.send();
      var responseData = await response.stream.bytesToString();
      var jsonData = json.decode(responseData);
      String? imageUrl = jsonData['secure_url'];

      if (imageUrl != null) {
        await _firestore.collection('users').doc(uid).update({'profile': imageUrl});
        setState(() {
          profileImage = imageUrl;
          _selectedImage = null;
        });
      }
    } catch (e) {
      print('Error uploading to Cloudinary: $e');
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

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Wrap(
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
            leading: Icon(Icons.photo_library),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: _showImagePickerOptions,
              child: CircleAvatar(
                radius: 50,
                backgroundImage: _selectedImage != null
                    ? FileImage(_selectedImage!)
                    : profileImage.isNotEmpty
                        ? NetworkImage(profileImage)
                        : AssetImage("assets/default_profile.png") as ImageProvider,
              ),
            ),
            SizedBox(height: 10),
            _selectedImage != null
                ? ElevatedButton(
                    onPressed: _uploadToCloudinary,
                    child: Icon(Icons.check),
                  )
                : SizedBox.shrink(),
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
            // Display attendance information in a more structured format
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildAttendanceBox("Hadir", "$hadir", Colors.green),
                _buildAttendanceBox("Total Telat", "$totalTelat hari", Colors.red),
                _buildAttendanceBox("Waktu Telat", "$waktuTelat menit", Colors.orange),
              ],
            ),
            SizedBox(height: 20),
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
                            var timestamp = image['timestamp']?.toDate();
                            String formattedTimestamp = timestamp != null
                                ? "${timestamp.day}/${timestamp.month}/${timestamp.year} ${timestamp.hour}:${timestamp.minute}"
                                : "Timestamp unavailable";

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
                                  SizedBox(height: 5),
                                  Text(
                                    'Uploaded at: $formattedTimestamp',
                                    style: TextStyle(fontStyle: FontStyle.italic),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        );
                      },
                    )
                  : Center(child: CircularProgressIndicator()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceBox(String title, String value, Color color) {
    return Container(
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color),
      ),
      width: 100,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          SizedBox(height: 5),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}
