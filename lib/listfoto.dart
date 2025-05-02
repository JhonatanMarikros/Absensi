import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ListFotoPage extends StatefulWidget {
  final String uid;

  const ListFotoPage({Key? key, required this.uid}) : super(key: key);

  @override
  _ListFotoPageState createState() => _ListFotoPageState();
}

class _ListFotoPageState extends State<ListFotoPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<Map<String, dynamic>>> _getPhotosByUid() async {
    final doc = await _firestore.collection('photos').doc(widget.uid).get();
    if (doc.exists && doc.data() != null) {
      List<dynamic> rawList = doc['imageUrls'] ?? [];
      return List<Map<String, dynamic>>.from(rawList);
    }
    return [];
  }

  Future<void> _updateStatus(Map<String, dynamic> image, String newStatus) async {
    final docRef = _firestore.collection('photos').doc(widget.uid);
    final snapshot = await docRef.get();

    if (snapshot.exists && snapshot.data() != null) {
      List imageUrls = List.from(snapshot['imageUrls']);
      final index = imageUrls.indexWhere((img) => img['imageUrl'] == image['imageUrl']);

      if (index != -1) {
        imageUrls[index]['status'] = newStatus;
        await docRef.update({'imageUrls': imageUrls});

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Status updated to $newStatus')),
        );

        setState(() {}); // Refresh UI
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Foto User'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _getPhotosByUid(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Tidak ada foto.'));
          }

          final photos = snapshot.data!;

          return ListView.builder(
            itemCount: photos.length,
            itemBuilder: (context, index) {
              final image = photos[index];
              return Card(
                margin: const EdgeInsets.all(12),
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          image['imageUrl'],
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text('Status: ${image['status']}',
                          style: const TextStyle(fontWeight: FontWeight.w500)),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () =>
                                _updateStatus(image, "Approved"),
                            icon: const Icon(Icons.check),
                            label: const Text("Approve"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: () =>
                                _updateStatus(image, "Rejected"),
                            icon: const Icon(Icons.close),
                            label: const Text("Reject"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                            ),
                          ),
                        ],
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
