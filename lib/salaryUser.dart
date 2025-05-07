import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class SalaryUserPage extends StatelessWidget {
  final String uid;

  const SalaryUserPage({Key? key, required this.uid}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final salaryDocRef = FirebaseFirestore.instance.collection('salary').doc(uid);

    return Scaffold(
      appBar: AppBar(title: const Text('Slip Gaji Terbaru')),
      body: StreamBuilder<DocumentSnapshot>(
        stream: salaryDocRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Terjadi kesalahan saat memuat slip gaji'));
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
            return const Center(child: Text('Belum ada slip gaji yang tersedia.'));
          }

          final data = snapshot.data!;
          final salaryImagesData = List<Map<String, dynamic>>.from(data['salary_images'] ?? []);

          if (salaryImagesData.isEmpty) {
            return const Center(child: Text('Slip gaji belum tersedia.'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: salaryImagesData.map((imageData) {
                final imageUrl = imageData['salary_images'];
                final timestamp = imageData['timestamp'];

                String formattedTime = 'Waktu tidak tersedia';
                if (timestamp != null && timestamp is Timestamp) {
                  try {
                    final dt = timestamp.toDate();
                    formattedTime = DateFormat('dd-MM-yyyy HH:mm').format(dt);
                  } catch (_) {
                    formattedTime = 'Format waktu tidak valid';
                  }
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: 20.0),
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
    );
  }
}
