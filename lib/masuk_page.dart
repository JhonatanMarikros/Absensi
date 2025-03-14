import 'package:flutter/material.dart';
import 'camera.dart';
import 'upload_file.dart';

class MasukPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Halaman Masuk")),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) =>
                          CameraPage(statusCheckInCheckOut: "Masuk")),
                );
              },
              child: Text('Take Photo'),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) =>
                          UploadFilePage(statusCheckInCheckOut: "Masuk")),
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
