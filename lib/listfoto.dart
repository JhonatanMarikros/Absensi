import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'salary.dart';

typedef ImageData = Map<String, dynamic>;

class ListFotoPage extends StatefulWidget {
  final String uid;
  final String username;

  const ListFotoPage({Key? key, required this.uid, required this.username})
      : super(key: key);

  @override
  _ListFotoPageState createState() => _ListFotoPageState();
}

class _ListFotoPageState extends State<ListFotoPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  int? hadir;
  int? totalTelat;
  int? waktuTelat;

  late Stream<DocumentSnapshot<Map<String, dynamic>>> _photosStream;

  @override
  void initState() {
    super.initState();
    _photosStream = _firestore.collection('photos').doc(widget.uid).snapshots();
  }

  Future<void> _updateStatus(
    String uid,
    ImageData image,
    String newStatus,
  ) async {
    try {
      DocumentReference docRef = _firestore.collection('photos').doc(uid);
      DocumentSnapshot snapshot = await docRef.get();

      if (!snapshot.exists) return;

      List<dynamic> imageUrls = List.from(snapshot['imageUrls'] ?? []);

      // Update status untuk foto tertentu
      for (var img in imageUrls) {
        if (img['imageUrl'] == image['imageUrl']) {
          if (img['statusCheckedIn'] == true ||
              img['statusCheckedOut'] == true) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Foto ini sudah diproses sebelumnya")),
            );
            return;
          }

          img['status'] = newStatus;
        }
      }

      await docRef.update({'imageUrls': imageUrls});

      // Filter check-in dan check-out yang disetujui dan belum dihitung sebelumnya
      var checkIns = imageUrls
          .where((img) =>
              img['statusCheckInCheckOut'] == 'Masuk' &&
              img['status'] == 'Approved' &&
              img['timestamp'] is Timestamp &&
              (img['statusCheckedIn'] != true)) // Hanya yang belum dihitung
          .toList();

      var checkOuts = imageUrls
          .where((img) =>
              img['statusCheckInCheckOut'] == 'Keluar' &&
              img['status'] == 'Approved' &&
              img['timestamp'] is Timestamp &&
              (img['statusCheckedOut'] != true)) // Hanya yang belum dihitung
          .toList();

      // Kelompokkan berdasarkan tanggal lokal
      Map<String, List<Map<String, dynamic>>> groupedIns = {};
      Map<String, List<Map<String, dynamic>>> groupedOuts = {};

      for (var checkIn in checkIns) {
        DateTime date = (checkIn['timestamp'] as Timestamp).toDate().toLocal();
        String key =
            "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
        groupedIns.putIfAbsent(key, () => []).add(checkIn);
      }

      for (var checkOut in checkOuts) {
        DateTime date = (checkOut['timestamp'] as Timestamp).toDate().toLocal();
        String key =
            "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
        groupedOuts.putIfAbsent(key, () => []).add(checkOut);
      }

      int newHadir = 0;
      int newTotalTelat = 0;
      int newWaktuTelat = 0;

      for (var key in groupedIns.keys) {
        var ins = groupedIns[key]!;
        var outs = groupedOuts[key] ?? [];

        ins.sort((a, b) => (a['timestamp'] as Timestamp)
            .toDate()
            .compareTo((b['timestamp'] as Timestamp).toDate()));
        outs.sort((a, b) => (b['timestamp'] as Timestamp)
            .toDate()
            .compareTo((a['timestamp'] as Timestamp).toDate()));

        if (ins.isNotEmpty && outs.isNotEmpty) {
          var inTime = (ins.first['timestamp'] as Timestamp).toDate().toLocal();
          var outTime =
              (outs.first['timestamp'] as Timestamp).toDate().toLocal();
          var diff = outTime.difference(inTime);

          // Validasi 12 jam kerja dan checkout >= jam 20
          if (diff.inHours >= 12 && outTime.hour >= 20) {
            newHadir++;

            if (inTime.hour >= 8) {
              int telatMenit = ((inTime.hour - 8) * 60) + inTime.minute;
              newWaktuTelat += telatMenit;
              newTotalTelat++;
            }

            // Tandai sebagai sudah dihitung
            for (var img in ins) {
              img['statusCheckedIn'] = true;
            }
            for (var img in outs) {
              img['statusCheckedOut'] = true;
            }
          }
        }
      }

      // Ambil atau buat statistik
      Map<String, dynamic> oldStats;
      final data = snapshot.data() as Map<String, dynamic>?;

      if (data != null && data.containsKey('statistics')) {
        oldStats = Map<String, dynamic>.from(data['statistics']);
      } else {
        oldStats = {
          'hadir': 0,
          'totalTelat': 0,
          'waktuTelat': 0,
        };
        await docRef.update({'statistics': oldStats});
      }

      int totalHadir = oldStats['hadir'] + newHadir;
      int totalTelat = oldStats['totalTelat'] + newTotalTelat;
      int totalWaktuTelat = oldStats['waktuTelat'] + newWaktuTelat;

      await docRef.update({
        'statistics': {
          'hadir': totalHadir,
          'totalTelat': totalTelat,
          'waktuTelat': totalWaktuTelat,
        },
        'imageUrls': imageUrls, // perbarui flag status checked
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Foto diproses. Hadir: $totalHadir, Telat: $totalTelat hari, Total Telat: $totalWaktuTelat menit",
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}")),
      );
    }
  }

  Future<void> _deletePhoto(String uid, ImageData image) async {
    try {
      DocumentReference docRef = _firestore.collection('photos').doc(uid);
      DocumentSnapshot snapshot = await docRef.get();

      if (!snapshot.exists) return;

      List<dynamic> imageUrls = List.from(snapshot['imageUrls'] ?? []);
      imageUrls.removeWhere((img) => img['imageUrl'] == image['imageUrl']);

      await docRef.update({'imageUrls': imageUrls});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Foto berhasil dihapus")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error saat menghapus: ${e.toString()}")),
      );
    }
  }

  void _confirmResetDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Konfirmasi Reset"),
          content: Text(
              "Anda yakin ingin reset ulang data kehadiran ${widget.username}? Jika reset ulang maka foto yang masih ada akan berubah menjadi pending dan menghapus semua data kehadiran"),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Batal"),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _resetStatistics();
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text("Reset"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _resetStatistics() async {
    try {
      DocumentReference docRef =
          _firestore.collection('photos').doc(widget.uid);
      DocumentSnapshot snapshot = await docRef.get();

      if (!snapshot.exists) return;

      List<dynamic> imageUrls = List.from(snapshot['imageUrls'] ?? []);

      // Ubah status menjadi 'Pending' jika foto masih ada
      for (var img in imageUrls) {
        if (img.containsKey('imageUrl')) {
          img['status'] = 'pending';
          img.remove('statusCheckedIn');
          img.remove('statusCheckedOut');
        }
      }

      await docRef.update({
        'statistics': FieldValue.delete(),
        'imageUrls': imageUrls,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text("Data kehadiran berhasil di-reset dan statistik dihapus")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error saat reset: ${e.toString()}")),
      );
    }
  }

  Future<void> _undoApproval(String uid, ImageData image) async {
    try {
      DocumentReference docRef = _firestore.collection('photos').doc(uid);
      DocumentSnapshot snapshot = await docRef.get();

      if (!snapshot.exists) return;

      List<dynamic> imageUrls = List.from(snapshot['imageUrls'] ?? []);
      final data = snapshot.data() as Map<String, dynamic>;

      int dikurangHadir = 0;
      int dikurangTelat = 0;
      int dikurangWaktuTelat = 0;

      for (var img in imageUrls) {
        if (img['imageUrl'] == image['imageUrl']) {
          if (img['status'] == 'Approved') {
            final imgTimestamp =
                (img['timestamp'] as Timestamp).toDate().toLocal();

            if (img['statusCheckedIn'] == true ||
                img['statusCheckedOut'] == true) {
              if (img['statusCheckInCheckOut'] == 'Masuk') {
                dikurangHadir = 1;
                if (imgTimestamp.hour >= 8) {
                  dikurangTelat = 1;
                  dikurangWaktuTelat =
                      ((imgTimestamp.hour - 8) * 60) + imgTimestamp.minute;
                }
              } else if (img['statusCheckInCheckOut'] == 'Keluar') {
                // Cari pasangan masuk di tanggal yang sama
                for (var otherImg in imageUrls) {
                  if (otherImg['statusCheckInCheckOut'] == 'Masuk' &&
                      (otherImg['timestamp'] as Timestamp)
                              .toDate()
                              .toLocal()
                              .day ==
                          imgTimestamp.day &&
                      (otherImg['timestamp'] as Timestamp)
                              .toDate()
                              .toLocal()
                              .month ==
                          imgTimestamp.month &&
                      (otherImg['timestamp'] as Timestamp)
                              .toDate()
                              .toLocal()
                              .year ==
                          imgTimestamp.year &&
                      otherImg['statusCheckedIn'] == true) {
                    // Jika pasangan ditemukan, kurangi statistik
                    dikurangHadir = 1;
                    if ((otherImg['timestamp'] as Timestamp)
                            .toDate()
                            .toLocal()
                            .hour >=
                        8) {
                      dikurangTelat = 1;
                      dikurangWaktuTelat =
                          (((otherImg['timestamp'] as Timestamp)
                                          .toDate()
                                          .toLocal()
                                          .hour -
                                      8) *
                                  60) +
                              ((otherImg['timestamp'] as Timestamp)
                                  .toDate()
                                  .toLocal()
                                  .minute);
                    }

                    // Reset pasangan
                    otherImg.remove('statusCheckedIn');
                    otherImg.remove('statusCheckedOut');
                    break;
                  }
                }
              }

              // Reset pasangan di tanggal yang sama
              for (var otherImg in imageUrls) {
                if (otherImg['imageUrl'] != img['imageUrl'] &&
                    (otherImg['timestamp'] as Timestamp)
                            .toDate()
                            .toLocal()
                            .day ==
                        imgTimestamp.day &&
                    (otherImg['timestamp'] as Timestamp)
                            .toDate()
                            .toLocal()
                            .month ==
                        imgTimestamp.month &&
                    (otherImg['timestamp'] as Timestamp)
                            .toDate()
                            .toLocal()
                            .year ==
                        imgTimestamp.year) {
                  otherImg.remove('statusCheckedIn');
                  otherImg.remove('statusCheckedOut');
                }
              }

              // Reset status sendiri
              if (img['statusCheckInCheckOut'] == 'Masuk') {
                img.remove('statusCheckedIn');
              } else if (img['statusCheckInCheckOut'] == 'Keluar') {
                img.remove('statusCheckedOut');
              }
            }

            img['status'] = 'pending';
          }
        }
      }

      // Kurangi statistik
      Map<String, dynamic> stats = data['statistics'] ??
          {
            'hadir': 0,
            'totalTelat': 0,
            'waktuTelat': 0,
          };

      stats['hadir'] =
          (stats['hadir'] - dikurangHadir).clamp(0, double.infinity);
      stats['totalTelat'] =
          (stats['totalTelat'] - dikurangTelat).clamp(0, double.infinity);
      stats['waktuTelat'] =
          (stats['waktuTelat'] - dikurangWaktuTelat).clamp(0, double.infinity);

      await docRef.update({
        'imageUrls': imageUrls,
        'statistics': stats,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text("Status foto berhasil di-undo dan statistik dikoreksi")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error saat undo: ${e.toString()}")),
      );
    }
  }

  Widget _buildStatBox(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.black54)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Foto User')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _photosStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final doc = snapshot.data;
          if (doc == null || !doc.exists) {
            return const Center(child: Text("Data tidak ditemukan."));
          }

          final data = doc.data()!;
          final List<dynamic> rawList = data['imageUrls'] ?? [];
          final List<Map<String, dynamic>> photos =
              List<Map<String, dynamic>>.from(rawList);

          final statistics = data['statistics'] ?? {};
          hadir = statistics['hadir'] ?? 0;
          totalTelat = statistics['totalTelat'] ?? 0;
          waktuTelat = statistics['waktuTelat'] ?? 0;

          return ListView.builder(
            itemCount: photos.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black12,
                            blurRadius: 8,
                            offset: Offset(0, 4))
                      ],
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("📊 Statistik Kehadiran",
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildStatBox("Hadir", "$hadir"),
                            _buildStatBox("Telat", "$totalTelat hari"),
                            _buildStatBox("Waktu Telat", "$waktuTelat mnt"),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: ElevatedButton.icon(
                            onPressed: _confirmResetDialog,
                            icon: const Icon(Icons.refresh),
                            label: const Text("Reset Kehadiran"),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent),
                          ),
                        ),
                        // Tombol untuk upload slip gaji
                        const SizedBox(height: 20),
                        Align(
                          alignment: Alignment.centerRight,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              // Navigasi ke halaman salary.dart untuk upload foto slip gaji
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => SalaryPage(
                                    uid: widget.uid,
                                    username: widget.username,
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.upload),
                            label: const Text("Upload Slip Gaji"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final image = photos[index - 1];
              var timestamp = image['timestamp']?.toDate();
              String formattedTimestamp = timestamp != null
                  ? "${timestamp.day}/${timestamp.month}/${timestamp.year} ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}"
                  : "Timestamp unavailable";

              return Card(
                margin: const EdgeInsets.all(12),
                elevation: 3,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Align(
                        alignment: Alignment.topRight,
                        child: PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'undo') {
                              _undoApproval(widget.uid, image);
                            }
                          },
                          itemBuilder: (context) => [
                            if (image['status'] == 'Approved' &&
                                (image['statusCheckedIn'] == true ||
                                    image['statusCheckedOut'] == true))
                              const PopupMenuItem(
                                value: 'undo',
                                child: Text('Undo Approved'),
                              ),
                          ],
                        ),
                      ),
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
                      const SizedBox(height: 4),
                      Text(
                          'Check-In/Out: ${image['statusCheckInCheckOut'] ?? 'Tidak diketahui'}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              color: Colors.black54)),
                      const SizedBox(height: 4),
                      Text('Waktu: $formattedTimestamp',
                          style: const TextStyle(color: Colors.grey)),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          if (!(image['statusCheckedIn'] == true ||
                              image['statusCheckedOut'] == true)) ...[ 
                            ElevatedButton.icon(
                              onPressed: () =>
                                  _updateStatus(widget.uid, image, "Approved"),
                              icon: const Icon(Icons.check),
                              label: const Text("Approve"),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green),
                            ),
                            ElevatedButton.icon(
                              onPressed: () =>
                                  _updateStatus(widget.uid, image, "Rejected"),
                              icon: const Icon(Icons.close),
                              label: const Text("Reject"),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red),
                            ),
                          ],
                          ElevatedButton.icon(
                            onPressed: () => _deletePhoto(widget.uid, image),
                            icon: const Icon(Icons.delete),
                            label: const Text("Delete"),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey[700]),
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