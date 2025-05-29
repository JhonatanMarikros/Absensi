import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:ntp/ntp.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

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
  bool _isUploading = false;
  bool _isCapturing = false;
  Position? _currentPosition;
  String? _currentAddress;

  final double targetLatitude = -6.1659966;
  final double targetLongitude = 106.6149330;

  double? _distanceInMeters;

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

  Future<void> _getLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print('Layanan lokasi tidak aktif');
      await Geolocator.openLocationSettings();
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        print('Izin lokasi ditolak');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      print('Izin lokasi ditolak permanen');
      return;
    }

    try {
      _currentPosition = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      print('Lokasi berhasil: $_currentPosition');

      // Hitung jarak dari lokasi tetap
      await _calculateDistance();

      // Dapatkan alamat lengkap dari lat,long
      _currentAddress = await getAddressFromLatLng(
          _currentPosition!.latitude, _currentPosition!.longitude);
      print('Alamat lengkap: $_currentAddress');
    } catch (e) {
      print('Gagal mendapatkan lokasi atau alamat: $e');
    }
  }

  Future<String> getAddressFromLatLng(double latitude, double longitude) async {
    try {
      List<Placemark> placemarks =
          await placemarkFromCoordinates(latitude, longitude);

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;

        String jalan = (place.street != null && place.street!.isNotEmpty)
            ? place.street!
            : '';
        String rtRw =
            (place.subThoroughfare != null && place.subThoroughfare!.isNotEmpty)
                ? place.subThoroughfare!
                : '';
        String kelurahan = place.subLocality ?? '';
        String kecamatan = place.locality ?? '';
        String kota = place.subAdministrativeArea ?? '';
        String provinsi = place.administrativeArea ?? '';
        String negara = place.country ?? '';
        String kodePos = place.postalCode ?? '';

        // Gabungkan alamat
        String fullAddress = [
          jalan,
          rtRw,
          kelurahan,
          kecamatan,
          kota,
          provinsi,
          kodePos,
          negara
        ].where((element) => element.isNotEmpty).join(', ');

        return fullAddress;
      } else {
        return "Alamat tidak ditemukan";
      }
    } catch (e) {
      print('Error pada geocoding: $e');
      return "Error mendapatkan alamat";
    }
  }

  Future<void> _calculateDistance() async {
    if (_currentPosition != null) {
      _distanceInMeters = Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        targetLatitude,
        targetLongitude,
      );
      print('Jarak dari lokasi tetap: $_distanceInMeters meter');
    }
  }

  Future<void> _capturePhoto() async {
    try {
      await _getLocation();

      // if (_distanceInMeters != null && _distanceInMeters! >= 10) {
      //   _showDiluarRadiusDialog(); // tampilkan dialog larangan
      //   return; // hentikan proses, tidak lanjut ambil foto
      // }

      setState(() => _isCapturing = true);

      await _initializeControllerFuture;
      final image = await _controller.takePicture();
      setState(() {
        _capturedImage = File(image.path);
        _isCapturing = false;
      });
    } catch (e) {
      print('Error: $e');
      setState(() => _isCapturing = false);
    }
  }

  Future<void> _submitPhoto() async {
    if (_capturedImage == null) return;

    setState(() => _isUploading = true);

    try {
      if (_currentPosition == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Gagal mendapatkan lokasi. Pastikan lokasi aktif dan diizinkan.')),
        );
        setState(() => _isUploading = false);
        return;
      }

      User? user = _auth.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User not logged in!')),
        );
        setState(() => _isUploading = false);
        return;
      }

      String uid = user.uid;

      DocumentSnapshot userSnapshot =
          await _firestore.collection('users').doc(uid).get();
      String username = '';
      if (userSnapshot.exists && userSnapshot.data() != null) {
        final data = userSnapshot.data() as Map<String, dynamic>;
        username = data['username'] ?? '';
      }

      DateTime ntpTime = await NTP.now();
      String today = "${ntpTime.year}-${ntpTime.month}-${ntpTime.day}";

      DocumentReference docRef = _firestore.collection('photos').doc(uid);
      DocumentSnapshot snapshot = await docRef.get();

      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        List<dynamic> images = data['imageUrls'] ?? [];

        bool alreadySubmitted = images.any((img) {
          final Timestamp timestamp = img['timestamp'];
          final String status = img['statusCheckInCheckOut'] ?? '';
          final date = timestamp.toDate();
          String submittedDate = "${date.year}-${date.month}-${date.day}";

          return submittedDate == today &&
              status == widget.statusCheckInCheckOut;
        });

        if (alreadySubmitted) {
          _showAbsensiSudahAdaDialog();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'You have already submitted ${widget.statusCheckInCheckOut} for today.')),
          );
          setState(() => _isUploading = false);
          return;
        }
      }

      String? imageUrl = await _uploadToCloudinary(_capturedImage!);

      if (imageUrl != null) {
        Map<String, dynamic> newImage = {
          'imageUrl': imageUrl,
          'status': 'pending',
          'timestamp': Timestamp.fromDate(ntpTime),
          'statusCheckInCheckOut': widget.statusCheckInCheckOut,
          'location': {
            'latitude': _currentPosition!.latitude,
            'longitude': _currentPosition!.longitude,
            'address': _currentAddress ?? 'Alamat tidak tersedia',
            'radius': _distanceInMeters != null
                ? _distanceInMeters!.toStringAsFixed(2) + ' meter'
                : 'Tidak diketahui',
          },
        };

        if (snapshot.exists) {
          await docRef.update({
            'username': username,
            'imageUrls': FieldValue.arrayUnion([newImage]),
          });
        } else {
          await docRef.set({
            'username': username,
            'imageUrls': [newImage],
          });
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo uploaded successfully!')),
        );

        setState(() {
          _capturedImage = null;
          _isUploading = false;
        });

        Navigator.pop(context);
      } else {
        setState(() => _isUploading = false);
      }
    } catch (e) {
      print('Error during submission: $e');
      setState(() => _isUploading = false);
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

  void _showAbsensiSudahAdaDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Absensi Ditolak"),
          content: Text(
              "Anda sudah melakukan absensi ${widget.statusCheckInCheckOut} hari ini."),
          actions: [
            TextButton(
              child: Text("OK"),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  void _showDiluarRadiusDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Absensi Ditolak"),
          content: Text(
            "Radius Anda di luar 10 meter dari kantor sehingga tidak bisa melakukan absensi.\n\n"
            "Jarak Anda saat ini: ${_distanceInMeters?.toStringAsFixed(2)} meter\n"
            "Alamat: ${_currentAddress ?? 'Tidak ditemukan'}",
          ),
          actions: [
            TextButton(
              child: Text("OK"),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
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
      body: _isUploading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Mengunggah absensi...',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            )
          : _isCapturing
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text(
                        'Mengambil foto...',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Expanded(
                      child: _capturedImage == null
                          ? FutureBuilder<void>(
                              future: _initializeControllerFuture,
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.done) {
                                  return CameraPreview(_controller);
                                } else {
                                  return const Center(
                                      child: CircularProgressIndicator());
                                }
                              },
                            )
                          : Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(_capturedImage!,
                                    fit: BoxFit.cover),
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
