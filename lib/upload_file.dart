import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:ntp/ntp.dart';

class UploadFilePage extends StatefulWidget {
  final String statusCheckInCheckOut;

  UploadFilePage({required this.statusCheckInCheckOut});

  @override
  _UploadFilePageState createState() => _UploadFilePageState();
}

class _UploadFilePageState extends State<UploadFilePage> {
  File? _selectedFile;
  bool _isSubmitting = false;

  final String cloudinaryUrl =
      "https://api.cloudinary.com/v1_1/dxmczui47/image/upload";
  final String uploadPreset = "absensi";

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  void _pickFile(BuildContext context, FileType fileType) async {
    try {
      FilePickerResult? result =
          await FilePicker.platform.pickFiles(type: fileType);
      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedFile = File(result.files.single.path!);
        });
      } else {
        print('User canceled or no file selected.');
      }
    } catch (e) {
      print("File picker error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Gagal mengambil file: $e")),
      );
    }
  }

  void _showFilePickerOptions(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Pilih Sumber File'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.image),
                title: Text('Galeri'),
                onTap: () {
                  Navigator.pop(context);
                  _pickFile(context, FileType.image);
                },
              ),
              ListTile(
                leading: Icon(Icons.insert_drive_file),
                title: Text('Dokumen'),
                onTap: () {
                  Navigator.pop(context);
                  _pickFile(context, FileType.any);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<String?> _uploadToCloudinary(File file) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse(cloudinaryUrl));
      request.fields['upload_preset'] = uploadPreset;
      request.files.add(await http.MultipartFile.fromPath('file', file.path));

      var response = await request.send();
      var responseData = await response.stream.bytesToString();
      var jsonData = json.decode(responseData);

      return jsonData['secure_url'];
    } catch (e) {
      print('Error uploading to Cloudinary: $e');
      return null;
    }
  }

  void _submitFile() async {
    if (_selectedFile != null) {
      setState(() {
        _isSubmitting = true;
      });

      try {
        User? user = _auth.currentUser;
        if (user == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Anda harus login terlebih dahulu!')),
          );
          return;
        }

        String uid = user.uid;

        // Ambil username dari Firestore
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

        // Cek apakah user sudah absen untuk status ini di hari yang sama
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
                    'Anda sudah melakukan ${widget.statusCheckInCheckOut} hari ini.'),
              ),
            );
            return;
          }
        }

        // Upload ke Cloudinary
        String? imageUrl = await _uploadToCloudinary(_selectedFile!);

        if (imageUrl != null) {
          Map<String, dynamic> newImage = {
            'imageUrl': imageUrl,
            'status': 'pending',
            'timestamp': Timestamp.fromDate(ntpTime),
            'statusCheckInCheckOut': widget.statusCheckInCheckOut,
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
            SnackBar(
                content:
                    Text('File berhasil diunggah dan disimpan ke database!')),
          );
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal mengunggah file!')),
          );
        }
      } finally {
        setState(() {
          _isSubmitting = false;
        });
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Pilih file terlebih dahulu!')),
      );
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
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

@override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        backgroundColor: Colors.indigo[900],
        title: Text(
          'Upload Attendance File',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        elevation: 4,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_selectedFile == null) ...[
                  Icon(Icons.cloud_upload, size: 80, color: Colors.white70),
                  SizedBox(height: 12),
                  Text(
                    'Silakan unggah foto atau dokumen\nuntuk keperluan absensi',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  SizedBox(height: 24),
                  ElevatedButton(
                    onPressed:
                        _isSubmitting ? null : () => _showFilePickerOptions(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo[900],
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      'Pilih File',
                      style: TextStyle(fontSize: 18, color: Colors.white),
                    ),
                  ),
                ] else ...[
                  Container(
                    constraints: BoxConstraints(maxHeight: 300),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: _selectedFile!.path.endsWith('.jpg') ||
                              _selectedFile!.path.endsWith('.jpeg') ||
                              _selectedFile!.path.endsWith('.png')
                          ? Image.file(_selectedFile!, fit: BoxFit.cover)
                          : Center(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.insert_drive_file,
                                        color: Colors.white70, size: 50),
                                    SizedBox(height: 10),
                                    Text(
                                      _selectedFile!.path.split('/').last,
                                      style: TextStyle(
                                          color: Colors.white70, fontSize: 16),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                    ),
                  ),
                  SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _isSubmitting
                        ? null
                        : () => _showFilePickerOptions(context),
                    icon: Icon(Icons.refresh),
                    label: Text("Ganti File"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      padding:
                          EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  SizedBox(height: 12),
                  if (!_isSubmitting)
                    ElevatedButton(
                      onPressed: _submitFile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        'Submit File',
                        style: TextStyle(fontSize: 18, color: Colors.white),
                      ),
                    ),
                  if (_isSubmitting) ...[
                    SizedBox(height: 16),
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 10),
                    Text(
                      'Proses submit file...',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ]
              ],
            ),
          ),
        ),
      ),
    );
  }
}