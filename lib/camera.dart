import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:ntp/ntp.dart';

class CameraPage extends StatefulWidget {
  final String statusCheckInCheckOut;

  CameraPage({required this.statusCheckInCheckOut});

  @override
  _CameraPageState createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  late List<CameraDescription> cameras;
  int selectedCameraIndex = 0;
  File? _capturedImage;
  final String cloudinaryUrl =
      "https://api.cloudinary.com/v1_1/dxmczui47/image/upload";
  final String uploadPreset = "absensi";
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      cameras = await availableCameras();
      _controller = CameraController(
        cameras[selectedCameraIndex],
        ResolutionPreset.medium,
      );
      _initializeControllerFuture = _controller.initialize();
      setState(() {});
    } catch (e) {
      print('Error initializing camera: $e');
    }
  }

  Future<void> _switchCamera() async {
    if (cameras.isEmpty) return;

    selectedCameraIndex = (selectedCameraIndex + 1) % cameras.length;

    await _controller.dispose();
    _controller = CameraController(
      cameras[selectedCameraIndex],
      ResolutionPreset.medium,
    );

    _initializeControllerFuture = _controller.initialize();
    setState(() {});
  }

  Future<void> _capturePhoto() async {
    try {
      await _initializeControllerFuture;
      final image = await _controller.takePicture();
      setState(() {
        _capturedImage = File(image.path);
      });
    } catch (e) {
      print('Error: $e');
    }
  }

  Future<void> _submitPhoto() async {
  if (_capturedImage == null) return;

  User? user = _auth.currentUser;
  if (user == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('User not logged in!')),
    );
    return;
  }

  String uid = user.uid;

  // Ambil username dari koleksi 'users'
  DocumentSnapshot userSnapshot = await _firestore.collection('users').doc(uid).get();
  String username = '';
  if (userSnapshot.exists && userSnapshot.data() != null) {
    final data = userSnapshot.data() as Map<String, dynamic>;
    username = data['username'] ?? '';
  }

  String? imageUrl = await _uploadToCloudinary(_capturedImage!);
  DateTime ntpTime = await NTP.now();

  if (imageUrl != null) {
    DocumentReference docRef = _firestore.collection('photos').doc(uid);
    DocumentSnapshot snapshot = await docRef.get();

    Map<String, dynamic> newImage = {
      'imageUrl': imageUrl,
      'status': 'pending',
      'timestamp': Timestamp.fromDate(ntpTime),
      'statusCheckInCheckOut': widget.statusCheckInCheckOut,
    };

    if (snapshot.exists) {
      await docRef.update({
        'username': username, // ✅ Update username jika berubah
        'imageUrls': FieldValue.arrayUnion([newImage]),
      });
    } else {
      await docRef.set({
        'username': username, // ✅ Simpan username di luar array image
        'imageUrls': [newImage],
      });
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Photo uploaded successfully!')),
    );

    setState(() {
      _capturedImage = null;
    });

    Navigator.pop(context);
  }
}

  Future<String?> _uploadToCloudinary(File imageFile) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse(cloudinaryUrl));
      request.fields['upload_preset'] = uploadPreset;
      request.files
          .add(await http.MultipartFile.fromPath('file', imageFile.path));

      var response = await request.send();
      var responseData = await response.stream.bytesToString();
      var jsonData = json.decode(responseData);

      return jsonData['secure_url'];
    } catch (e) {
      print('Error uploading to Cloudinary: $e');
      return null;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        backgroundColor: Colors.indigo[900],
        title: Text(
          'Take Attendance Photo',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        elevation: 4,
        actions: [
          IconButton(
            icon: Icon(Icons.switch_camera, color: Colors.white),
            onPressed: _switchCamera,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _capturedImage == null
                ? FutureBuilder<void>(
                    future: _initializeControllerFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.done) {
                        return CameraPreview(_controller);
                      } else {
                        return const Center(child: CircularProgressIndicator());
                      }
                    },
                  )
                : Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(_capturedImage!, fit: BoxFit.cover),
                    ),
                  ),
          ),
          if (_capturedImage != null)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                onPressed: _submitPhoto,
                style: ElevatedButton.styleFrom(
                  primary: Colors.green,
                  padding: EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  'Submit Photo',
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: _capturePhoto,
              style: ElevatedButton.styleFrom(
                primary: Colors.indigo[900],
                padding: EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                'Capture Photo',
                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
