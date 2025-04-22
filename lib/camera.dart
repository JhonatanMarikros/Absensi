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
  String? imageUrl = await _uploadToCloudinary(_capturedImage!);

  DateTime ntpTime = await NTP.now();

  if (imageUrl != null) {
    DocumentReference docRef = _firestore.collection('photos').doc(uid);
    DocumentSnapshot snapshot = await docRef.get();

    Map<String, dynamic> newImage = {
      'imageUrl': imageUrl,
      'status': 'pending',
      'timestamp': Timestamp.fromDate(ntpTime),
      'statusCheckInCheckOut': widget.statusCheckInCheckOut, // ✅ Tambahkan status ini
    };

    if (snapshot.exists) {
      await docRef.update({
        'imageUrls': FieldValue.arrayUnion([newImage]),
      });
    } else {
      await docRef.set({
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
      appBar: AppBar(title: const Text('Camera Example')),
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
                : Image.file(_capturedImage!),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              FloatingActionButton(
                onPressed: _switchCamera,
                child: const Icon(Icons.switch_camera),
              ),
              FloatingActionButton(
                onPressed: _capturePhoto,
                child: const Icon(Icons.camera),
              ),
              if (_capturedImage != null)
                FloatingActionButton(
                  onPressed: _submitPhoto,
                  child: const Icon(Icons.upload),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
