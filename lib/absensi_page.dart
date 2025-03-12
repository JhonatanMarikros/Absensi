import 'package:flutter/material.dart';
import 'camera.dart'; // Impor CameraPage dari camera.dart
import 'upload_file.dart'; // Impor UploadFilePage dari upload_file.dart

class AbsensiPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => CameraPage()), // Navigasi ke CameraPage
                );
              },
              child: Text('Take Photo'),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => UploadFilePage()), // Navigasi ke UploadFilePage
                );
              },
              child: Text('Upload File'),
            ),
          ],
        ),
      ),
    );
  }
}
