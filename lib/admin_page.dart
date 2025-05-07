import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:app_settings/app_settings.dart';
import 'dart:convert';
import 'registerLogin.dart';
import 'listfoto.dart';

typedef ImageData = Map<String, dynamic>;

class AdminHomePage extends StatefulWidget {
  @override
  _AdminHomePageState createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  String? selectedUserId;

  @override
  void initState() {
    super.initState();
    dotenv.load(fileName: ".env");
  }

  void _logout() async {
    await _auth.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => AuthScreen()),
    );
  }

  Future<void> _addAdmin() async {
    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showDialogAdmin("Email dan Password tidak boleh kosong!");
      return;
    }

    if (password.length < 6) {
      _showDialogAdmin("Password harus minimal 6 karakter");
      return;
    }

    try {
      UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);

      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'uid': userCredential.user!.uid,
        'email': email,
        'role': 'admin',
      });

      _emailController.clear();
      _passwordController.clear();

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text("Sukses"),
          content: Text("Admin berhasil ditambahkan!"),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text("OK"),
            )
          ],
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        _showDialogAdmin("Email tersebut sudah terdaftar, buat yang baru");
      } else {
        _showDialogAdmin("Terjadi kesalahan: ${e.message}");
      }
    } catch (e) {
      _showDialogAdmin("Terjadi kesalahan: ${e.toString()}");
    }
  }

  void _showDialogAdmin(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Peringatan"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text("OK"),
          )
        ],
      ),
    );
  }

  Future<String> _getUsername(String uid) async {
    DocumentSnapshot userDoc =
        await _firestore.collection('users').doc(uid).get();
    return userDoc.exists ? userDoc['username'] ?? 'Unknown' : 'Unknown';
  }

  Future<void> _deleteFromCloudinary(String imageUrl) async {
    try {
      String? cloudName = dotenv.env['CLOUDINARY_CLOUD_NAME'];
      String? apiKey = dotenv.env['CLOUDINARY_API_KEY'];
      String? apiSecret = dotenv.env['CLOUDINARY_API_SECRET'];

      if (cloudName == null || apiKey == null || apiSecret == null) {
        print("Error: Cloudinary credentials are missing.");
        return;
      }

      Uri uri = Uri.parse(imageUrl);
      String fileName = uri.pathSegments.last.split('.').first;
      String publicId = "absensi/$fileName";

      String timestamp =
          (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
      String stringToSign =
          'public_id=$publicId&timestamp=$timestamp$apiSecret';
      String signature = sha1.convert(utf8.encode(stringToSign)).toString();

      String apiUrl =
          'https://api.cloudinary.com/v1_1/$cloudName/image/destroy';

      var response = await http.post(
        Uri.parse(apiUrl),
        body: {
          'public_id': publicId,
          'api_key': apiKey,
          'timestamp': timestamp,
          'signature': signature,
          'invalidate': 'true',
        },
      );

      if (response.statusCode == 200) {
        print("✅ Berhasil menghapus dari Cloudinary.");
      } else {
        print("⚠️ Gagal menghapus dari Cloudinary: ${response.body}");
      }
    } catch (e) {
      print("❌ Error menghapus dari Cloudinary: $e");
    }
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return "Timestamp unavailable";
    try {
      final time = (timestamp is Timestamp) ? timestamp.toDate() : timestamp;
      return "${time.day}/${time.month}/${time.year} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";
    } catch (e) {
      return "Invalid timestamp";
    }
  }

  void _toggleUserPhotos(String uid) {
    setState(() {
      selectedUserId = selectedUserId == uid ? null : uid;
    });
  }

  Future<void> _exportPhotosToExcel(BuildContext context) async {
    try {
      var status = await Permission.manageExternalStorage.request();
      if (!status.isGranted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: Text("Akses Ditolak"),
            content: Text("❌ Izin akses penyimpanan ditolak."),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("OK"),
              )
            ],
          ),
        );
        return;
      }

      var excel = Excel.createExcel();

      // Hapus sheet default jika ada dan bukan sheet kita
      if (excel.sheets.containsKey('Sheet1')) {
        excel.delete('Sheet1');
      }

      String sheetName = 'Photos';
      Sheet sheetObject = excel[sheetName];

      // Header
      sheetObject.appendRow([
        'Username',
        'Kehadiran',
        'Total Telat (Hari)',
        'Waktu Telat (Menit)',
        'Image URL',
        'Status',
        'CheckIn/Out',
        'Timestamp',
      ]);

      // Ambil semua data user
      QuerySnapshot usersSnapshot =
          await FirebaseFirestore.instance.collection('users').get();
      Map<String, String> uidToUsername = {};
      for (var userDoc in usersSnapshot.docs) {
        var userData = userDoc.data() as Map<String, dynamic>;
        uidToUsername[userDoc.id] = userData['username'] ?? 'Unknown';
      }

      // Ambil data dari koleksi photos
      QuerySnapshot snapshot =
          await FirebaseFirestore.instance.collection('photos').get();

      for (var doc in snapshot.docs) {
        String uid = doc.id;
        var data = doc.data() as Map<String, dynamic>;

        String username = uidToUsername[uid] ?? 'Unknown';

        int hadir = 0;
        int totalTelat = 0;
        int waktuTelat = 0;

        if (data.containsKey('statistics')) {
          Map<String, dynamic> stats =
              Map<String, dynamic>.from(data['statistics']);
          hadir = stats['hadir'] ?? 0;
          totalTelat = stats['totalTelat'] ?? 0;
          waktuTelat = stats['waktuTelat'] ?? 0;
        }

        bool isFirst = true;

        if (data.containsKey('imageUrls') && data['imageUrls'] is List) {
          List<dynamic> imageUrls = data['imageUrls'];

          for (var img in imageUrls) {
            sheetObject.appendRow([
              isFirst ? username : '',
              isFirst ? hadir : '',
              isFirst ? totalTelat : '',
              isFirst ? waktuTelat : '',
              img['imageUrl'] ?? '',
              img['status'] ?? '',
              img['statusCheckInCheckOut'] ?? '',
              img['timestamp'] != null
                  ? (img['timestamp'] as Timestamp).toDate().toString()
                  : '',
            ]);
            isFirst = false;
          }
        }
      }

      // Simpan file dengan nama unik
      final downloadsDir = Directory('/storage/emulated/0/Download');
      if (!downloadsDir.existsSync()) {
        downloadsDir.createSync(recursive: true);
      }

      int index = 0;
      String filename = 'rekap_photos.xlsx';
      File file = File('${downloadsDir.path}/$filename');

      while (file.existsSync()) {
        index++;
        filename = 'rekap_photos$index.xlsx';
        file = File('${downloadsDir.path}/$filename');
      }

      file
        ..createSync(recursive: true)
        ..writeAsBytesSync(excel.encode()!);

      // Tampilkan popup sukses
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text("Sukses"),
          content: Text("✅ Data berhasil diekspor ke:\n${file.path}"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Tutup"),
            ),
          ],
        ),
      );
    } catch (e) {
      print("❌ Error saat ekspor: $e");
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text("Gagal"),
          content: Text("❌ Gagal ekspor data.\n${e.toString()}"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("OK"),
            ),
          ],
        ),
      );
    }
  }

  @override
  bool _showAddAdminForm = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          appBarTheme: AppBarTheme(
            backgroundColor: Colors.black, // Ganti warna latar belakang di sini
          ),
        ),
        home: Scaffold(
            appBar: AppBar(
              title: Row(
                children: [
                  Image.asset(
                    'assets/SBMNEW.png',
                    width: 60,
                    height: 60,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Admin Management',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: Icon(Icons.logout),
                  onPressed: _logout,
                ),
              ],
            ),
            body: SingleChildScrollView(
                child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Tombol toggle form tambah admin
                          ElevatedButton.icon(
                            onPressed: () {
                              setState(() {
                                _showAddAdminForm = !_showAddAdminForm;
                              });
                            },
                            icon: Icon(
                                _showAddAdminForm ? Icons.remove : Icons.add),
                            label: Text(_showAddAdminForm
                                ? "Tutup Form Admin"
                                : "Tambah Admin"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.indigo,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Form Tambah Admin dengan animasi
                          AnimatedCrossFade(
                            crossFadeState: _showAddAdminForm
                                ? CrossFadeState.showFirst
                                : CrossFadeState.showSecond,
                            duration: Duration(milliseconds: 300),
                            firstChild: Card(
                              elevation: 4,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  children: [
                                    Text(
                                      'Form Tambah Admin',
                                      style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 12),
                                    TextField(
                                      controller: _emailController,
                                      decoration: const InputDecoration(
                                        labelText: 'Email Admin',
                                        prefixIcon: Icon(Icons.email),
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    TextField(
                                      controller: _passwordController,
                                      obscureText: true,
                                      decoration: const InputDecoration(
                                        labelText: 'Password',
                                        prefixIcon: Icon(Icons.lock),
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    ElevatedButton.icon(
                                      onPressed: _addAdmin,
                                      icon: Icon(Icons.save),
                                      label: Text("Simpan Admin"),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.indigo,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 14),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            secondChild: SizedBox.shrink(),
                          ),

                          const SizedBox(height: 24),

                          // Tombol export excel
                          ElevatedButton.icon(
                            onPressed: () => _exportPhotosToExcel(context),
                            icon: const Icon(Icons.download),
                            label: const Text("Export Rekap ke Excel"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Daftar approval foto
                          StreamBuilder(
                            stream: _firestore.collection('photos').snapshots(),
                            builder: (context,
                                AsyncSnapshot<QuerySnapshot> snapshot) {
                              if (!snapshot.hasData) {
                                return const Center(
                                    child: CircularProgressIndicator());
                              }
                              return ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: snapshot.data!.docs.length,
                                itemBuilder: (context, index) {
                                  String uid = snapshot.data!.docs[index].id;
                                  Map<String, dynamic> data =
                                      snapshot.data!.docs[index].data()
                                          as Map<String, dynamic>;
                                  List imageUrls = data['imageUrls'] ?? [];

                                  return Card(
                                    margin: const EdgeInsets.symmetric(
                                        vertical: 10),
                                    elevation: 3,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                    child: Column(
                                      children: [
                                        ListTile(
                                          leading:
                                              FutureBuilder<DocumentSnapshot>(
                                            future: _firestore
                                                .collection('users')
                                                .doc(uid)
                                                .get(),
                                            builder: (context, userSnapshot) {
                                              if (userSnapshot
                                                      .connectionState ==
                                                  ConnectionState.waiting) {
                                                return const CircleAvatar(
                                                  backgroundColor: Colors.grey,
                                                  child: Icon(Icons.person,
                                                      color: Colors.white),
                                                );
                                              }
                                              if (userSnapshot.hasData &&
                                                  userSnapshot.data!.data() !=
                                                      null) {
                                                var userData =
                                                    userSnapshot.data!.data()
                                                        as Map<String, dynamic>;
                                                String? profileUrl =
                                                    userData['profile'];
                                                if (profileUrl != null &&
                                                    profileUrl.isNotEmpty) {
                                                  return CircleAvatar(
                                                    backgroundImage:
                                                        NetworkImage(
                                                            profileUrl),
                                                  );
                                                }
                                              }
                                              return const CircleAvatar(
                                                backgroundColor: Colors.grey,
                                                child: Icon(Icons.person,
                                                    color: Colors.white),
                                              );
                                            },
                                          ),
                                          title:
                                              StreamBuilder<DocumentSnapshot>(
                                            stream: _firestore
                                                .collection('users')
                                                .doc(uid)
                                                .snapshots(),
                                            builder: (context, userSnapshot) {
                                              if (userSnapshot
                                                      .connectionState ==
                                                  ConnectionState.waiting) {
                                                return const Text('Loading...');
                                              }
                                              if (userSnapshot.hasData &&
                                                  userSnapshot.data!.data() !=
                                                      null) {
                                                var userData =
                                                    userSnapshot.data!.data()
                                                        as Map<String, dynamic>;
                                                String username =
                                                    userData['username'] ??
                                                        'No Username';
                                                return Text(
                                                  'User: $username',
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600),
                                                );
                                              }
                                              return const Text('No Username');
                                            },
                                          ),
                                          trailing: Icon(
                                            selectedUserId == uid
                                                ? Icons.keyboard_arrow_up
                                                : Icons.keyboard_arrow_down,
                                          ),
                                          onTap: () {
                                            _firestore
                                                .collection('users')
                                                .doc(uid)
                                                .get()
                                                .then((userSnapshot) {
                                              if (userSnapshot.exists &&
                                                  userSnapshot.data() != null) {
                                                var userData =
                                                    userSnapshot.data()
                                                        as Map<String, dynamic>;
                                                String username =
                                                    userData['username'] ??
                                                        'Unknown';
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) =>
                                                        ListFotoPage(
                                                            uid: uid,
                                                            username: username),
                                                  ),
                                                );
                                              }
                                            });
                                          },
                                        ),
                                        if (selectedUserId == uid)
                                          Column(
                                            children:
                                                imageUrls.map<Widget>((image) {
                                              final timestamp =
                                                  image['timestamp'];
                                              final formattedTimestamp =
                                                  _formatTimestamp(timestamp);

                                              return Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 12,
                                                        vertical: 8),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    ClipRRect(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
                                                      child: Image.network(
                                                        image['imageUrl'],
                                                        height: 200,
                                                        width: double.infinity,
                                                        fit: BoxFit.cover,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 6),
                                                    Text(
                                                        'Status: ${image['status']}'),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      'Uploaded at: $formattedTimestamp',
                                                      style: const TextStyle(
                                                          fontStyle:
                                                              FontStyle.italic,
                                                          fontSize: 12),
                                                    ),
                                                    const SizedBox(height: 8),
                                                    const Divider(height: 30),
                                                  ],
                                                ),
                                              );
                                            }).toList(),
                                          )
                                      ],
                                    ),
                                  );
                                },
                              );
                            },
                          )
                        ])))));
  }
}
