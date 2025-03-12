import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class UploadFilePage extends StatefulWidget {
  @override
  _UploadFilePageState createState() => _UploadFilePageState();
}

class _UploadFilePageState extends State<UploadFilePage> {
  File? _selectedFile;
  final String cloudinaryUrl =
      "https://api.cloudinary.com/v1_1/dxmczui47/image/upload";
  final String uploadPreset = "absensi";

  final FirebaseAuth _auth = FirebaseAuth.instance;

  void _pickFile(BuildContext context, FileType fileType) async {
    FilePickerResult? result =
        await FilePicker.platform.pickFiles(type: fileType);
    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedFile = File(result.files.single.path!);
      });
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
    User? user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Anda harus login terlebih dahulu!')),
      );
      return;
    }

    String uid = user.uid;
    String? imageUrl = await _uploadToCloudinary(_selectedFile!);

    if (imageUrl != null) {
      DocumentReference docRef = FirebaseFirestore.instance.collection('photos').doc(uid);
      DocumentSnapshot snapshot = await docRef.get();

      Map<String, dynamic> newImage = {
        'imageUrl': imageUrl,
        'status': 'pending',
        'timestamp': Timestamp.now(), // ✅ Ganti FieldValue.serverTimestamp() dengan Timestamp.now()
      };

      if (snapshot.exists) {
        // Jika dokumen sudah ada, update array
        await docRef.update({
          'imageUrls': FieldValue.arrayUnion([
            {
              'imageUrl': imageUrl,
              'status': 'pending',
              'timestamp': Timestamp.now(), // Gunakan Timestamp.now()
            }
          ]),
        });
      } else {
        // Jika dokumen belum ada, buat baru
        await docRef.set({
          'imageUrls': [
            {
              'imageUrl': imageUrl,
              'status': 'pending',
              'timestamp': Timestamp.now(), // Gunakan Timestamp.now()
            }
          ]
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('File berhasil diunggah dan disimpan ke database!')),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengunggah file!')),
      );
    }
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Pilih file terlebih dahulu!')),
    );
  }
}



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Upload File')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed: () => _showFilePickerOptions(context),
              child: Text('Pilih File'),
            ),
            if (_selectedFile != null) ...[
              SizedBox(height: 16),
              Image.file(_selectedFile!,
                  width: 200, height: 200, fit: BoxFit.cover),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: _submitFile,
                child: Text('Submit'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
