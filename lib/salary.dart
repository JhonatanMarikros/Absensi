import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ntp/ntp.dart';
import 'package:intl/intl.dart';

class SalaryPage extends StatefulWidget {
  final String uid;
  final String username;

  SalaryPage({required this.uid, required this.username});

  @override
  _SalaryPageState createState() => _SalaryPageState();
}

class _SalaryPageState extends State<SalaryPage> {
  bool isUploading = false; // indikator loading

  Future<void> uploadSlipGajiToCloudinary(String uid, String username) async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.image,
    );

    if (result == null || result.files.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak ada gambar yang dipilih')),
      );
      return;
    }

    setState(() {
      isUploading = true; // mulai loading
    });

    List<Map<String, dynamic>> salaryImages = [];

    try {
      for (var file in result.files) {
        final filePath = file.path;
        if (filePath == null) continue;

        final uri = Uri.parse('https://api.cloudinary.com/v1_1/dxmczui47/image/upload');
        final request = http.MultipartRequest('POST', uri)
          ..fields['upload_preset'] = 'salary'
          ..files.add(await http.MultipartFile.fromPath('file', filePath));

        final response = await request.send();
        final responseData = await response.stream.bytesToString();

        if (response.statusCode == 200) {
          final responseJson = json.decode(responseData);
          final imageUrl = responseJson['secure_url'];

          salaryImages.add({
            'salary_images': imageUrl,
            'timestamp': Timestamp.fromDate(DateTime.now()),
          });
        } else {
          print('Upload gagal (${response.statusCode}): $responseData');
        }
      }

      if (salaryImages.isNotEmpty) {
        final DateTime ntpTime = await NTP.now();

        await FirebaseFirestore.instance.collection('salary').doc(uid).set({
          'username': username,
          'salary_images': FieldValue.arrayUnion(salaryImages),
        }, SetOptions(merge: true));

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Slip gaji berhasil diunggah untuk $username')),
        );
      } else {
        print('Tidak ada gambar yang berhasil diupload');
      }
    } catch (e) {
      print('Error saat upload: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Terjadi kesalahan: $e')),
      );
    } finally {
      setState(() {
        isUploading = false; // selesai loading
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upload Slip Gaji')),
      body: isUploading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 10),
                  Text('Mengunggah slip gaji...'),
                ],
              ),
            )
          : Column(
              children: [
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => uploadSlipGajiToCloudinary(widget.uid, widget.username),
                  child: const Text("Upload Slip Gaji"),
                ),
                const SizedBox(height: 20),
                Flexible(
                  child: StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('salary')
                        .doc(widget.uid)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (!snapshot.hasData || !snapshot.data!.exists) {
                        return const Center(child: Text('Belum ada slip gaji diunggah.'));
                      }

                      final data = snapshot.data!;
                      final salaryImagesData = List<Map<String, dynamic>>.from(
                        data['salary_images'] ?? [],
                      );

                      if (salaryImagesData.isEmpty) {
                        return const Center(child: Text('Tidak ada gambar yang diunggah.'));
                      }

                      return SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: salaryImagesData.map((imageData) {
                            final imageUrl = imageData['salary_images'];
                            final timestamp = imageData['timestamp'];

                            String formattedTime = 'Waktu tidak tersedia';
                            if (timestamp != null) {
                              try {
                                final dt = (timestamp as Timestamp).toDate();
                                formattedTime =
                                    DateFormat('dd-MM-yyyy HH:mm').format(dt);
                              } catch (_) {
                                formattedTime = 'Format waktu tidak valid';
                              }
                            }

                            return Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Image.network(imageUrl),
                                  const SizedBox(height: 5),
                                  Text('Diupload pada: $formattedTime'),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
