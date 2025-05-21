import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class SalaryUserPage extends StatelessWidget {
  final String uid;

  const SalaryUserPage({Key? key, required this.uid}) : super(key: key);

  void _showFullImage(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.all(16),
        child: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: InteractiveViewer(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final salaryDocRef =
        FirebaseFirestore.instance.collection('salary').doc(uid);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.indigo[900],
        title: const Text(
          'Slip Gaji Terbaru',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: salaryDocRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
                child: Text('Terjadi kesalahan saat memuat slip gaji'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 10),
                  Text('Sedang memuat...'),
                ],
              ),
            );
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(
                child: Text('Belum ada slip gaji yang tersedia.'));
          }

          final data = snapshot.data!;
          final salaryImagesData = List<Map<String, dynamic>>.from(
            data['salary_images'] ?? [],
          );

          if (salaryImagesData.isEmpty) {
            return const Center(child: Text('Slip gaji belum tersedia.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: salaryImagesData.length,
            itemBuilder: (context, index) {
              final imageData = salaryImagesData[index];
              final imageUrl = imageData['salary_images'];
              final timestamp = imageData['timestamp'];

              String formattedTime = 'Waktu tidak tersedia';
              if (timestamp != null && timestamp is Timestamp) {
                try {
                  final dt = timestamp.toDate();
                  formattedTime =
                      DateFormat('dd-MM-yyyy HH:mm').format(dt);
                } catch (_) {
                  formattedTime = 'Format waktu tidak valid';
                }
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () => _showFullImage(context, imageUrl),
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(12)),
                          child: AspectRatio(
                            aspectRatio: 4 / 3,
                            child: Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Text(
                          'Diupload pada: $formattedTime',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
