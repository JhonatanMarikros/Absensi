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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Email dan Password tidak boleh kosong!")),
      );
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Admin berhasil ditambahkan!")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}")),
      );
    }
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ Izin akses penyimpanan ditolak.")),
        );
        return;
      }

      var excel = Excel.createExcel();
      Sheet sheetObject = excel['Photos'];
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

      // Ambil data dari collection photos
      QuerySnapshot snapshot =
          await FirebaseFirestore.instance.collection('photos').get();

      for (var doc in snapshot.docs) {
        String uid = doc.id;
        var data = doc.data() as Map<String, dynamic>;

        String username = uidToUsername[uid] ?? 'Unknown';
        int hadir = data['hadir'] ?? 0;
        int totalTelat = data['totalTelat'] ?? 0;
        int waktuTelat = data['waktuTelat'] ?? 0;

        bool isFirst = true;

        if (data.containsKey('imageUrls') && data['imageUrls'] is List) {
          List<dynamic> imageUrls = data['imageUrls'];

          for (var img in imageUrls) {
            sheetObject.appendRow([
              isFirst ? username : '', // Tampilkan hanya sekali
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

            isFirst =
                false; // Setelah baris pertama, sisanya kosong untuk kolom pertama
          }
        }
      }

      final downloadsDir = Directory('/storage/emulated/0/Download');
      final path = "${downloadsDir.path}/rekap_photos.xlsx";

      File file = File(path)
        ..createSync(recursive: true)
        ..writeAsBytesSync(excel.encode()!);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("✅ Data berhasil diekspor ke: $path")),
      );
    } catch (e) {
      print("❌ Error saat ekspor: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Gagal ekspor data.")),
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
                icon: Icon(_showAddAdminForm ? Icons.remove : Icons.add),
                label: Text(
                    _showAddAdminForm ? "Tutup Form Admin" : "Tambah Admin"),
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
                              fontSize: 18, fontWeight: FontWeight.bold),
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
                            padding: const EdgeInsets.symmetric(vertical: 14),
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
                builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: snapshot.data!.docs.length,
                        itemBuilder: (context, index) {
                          String uid = snapshot.data!.docs[index].id;
                          Map<String, dynamic> data = snapshot.data!.docs[index]
                              .data() as Map<String, dynamic>;
                          List imageUrls = data['imageUrls'] ?? [];

                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 10),
                            elevation: 3,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            child: Column(
                              children: [
                                ListTile(
                                  leading: FutureBuilder<DocumentSnapshot>(
                                    future: _firestore.collection('users').doc(uid).get(),
                                    builder: (context, userSnapshot) {
                                      if (userSnapshot.connectionState == ConnectionState.waiting) {
                                        return const CircleAvatar(
                                          backgroundColor: Colors.grey,
                                          child: Icon(Icons.person, color: Colors.white),
                                        );
                                      }
                                      if (userSnapshot.hasData && userSnapshot.data!.data() != null) {
                                        var userData = userSnapshot.data!.data() as Map<String, dynamic>;
                                        String? profileUrl = userData['profile'];
                                        if (profileUrl != null && profileUrl.isNotEmpty) {
                                          return CircleAvatar(
                                            backgroundImage: NetworkImage(profileUrl),
                                          );
                                        }
                                      }
                                      return const CircleAvatar(
                                        backgroundColor: Colors.grey,
                                        child: Icon(Icons.person, color: Colors.white),
                                      );
                                    },
                                  ),

                                  title: FutureBuilder<String>(
                                    future: _getUsername(uid),
                                    builder: (context, userSnapshot) {
                                      return Text(
                                        'User: ${userSnapshot.data ?? 'Loading...'}',
                                        style: const TextStyle(fontWeight: FontWeight.w600),
                                      );
                                    },
                                  ),
                                  trailing: Icon(
                                    selectedUserId == uid
                                        ? Icons.keyboard_arrow_up
                                        : Icons.keyboard_arrow_down,
                                  ),
                                  onTap: () {
                                    // Navigasi ke halaman baru (ListFotoPage)
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ListFotoPage(uid: uid),
                                      ),
                                    );
                                  },
                                ),
                                if (selectedUserId == uid)
                                Column(
                                  children: imageUrls.map<Widget>((image) {
                                    final timestamp = image['timestamp'];
                                    final formattedTimestamp = _formatTimestamp(timestamp);

                                    return Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                                          const SizedBox(height: 6),
                                          Text('Status: ${image['status']}'),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Uploaded at: $formattedTimestamp',
                                            style: const TextStyle(
                                              fontStyle: FontStyle.italic,
                                              fontSize: 12,
                                            ),
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
          
            ]
          )))));
}
                            
                  
                  
          

// import 'package:flutter/material.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter_dotenv/flutter_dotenv.dart';
// import 'registerLogin.dart';

// typedef ImageData = Map<String, dynamic>;

// class AdminHomePage extends StatefulWidget {
//   @override
//   _AdminHomePageState createState() => _AdminHomePageState();
// }

// class _AdminHomePageState extends State<AdminHomePage> {
//   final FirebaseAuth _auth = FirebaseAuth.instance;
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;
//   final TextEditingController _emailController = TextEditingController();
//   final TextEditingController _passwordController = TextEditingController();

//   bool showFolders = false; // Untuk toggle daftar user
//   String? selectedUserId; // Untuk menandai user yang sedang diperiksa gambarnya

//   @override
//   void initState() {
//     super.initState();
//     dotenv.load(fileName: ".env");
//   }

//   void _logout() async {
//     await _auth.signOut();
//     Navigator.pushReplacement(
//       context,
//       MaterialPageRoute(builder: (context) => AuthScreen()),
//     );
//   }

//   Future<void> _addAdmin() async {
//     String email = _emailController.text.trim();
//     String password = _passwordController.text.trim();

//     if (email.isEmpty || password.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text("Email dan Password tidak boleh kosong!")),
//       );
//       return;
//     }

//     try {
//       UserCredential userCredential = await _auth.createUserWithEmailAndPassword(email: email, password: password);
//       await _firestore.collection('users').doc(userCredential.user!.uid).set({
//         'uid': userCredential.user!.uid,
//         'email': email,
//         'role': 'admin',
//       });

//       _emailController.clear();
//       _passwordController.clear();

//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text("Admin berhasil ditambahkan!")),
//       );
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text("Error: ${e.toString()}")),
//       );
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Row(
//           children: [
//             Image.asset(
//               'assets/SBMNEW.png', // Ganti dengan path logo perusahaan
//               height: 40, // Ukuran logo
//             ),
//             Spacer(),
//             Text(
//               'Admin',
//               style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//             ),
//           ],
//         ),
//         actions: [
//           IconButton(
//             icon: Icon(Icons.logout),
//             onPressed: _logout,
//           ),
//         ],
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           children: [
//             // FORM ADMIN DALAM CARD
//             Card(
//               elevation: 4,
//               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//               child: Padding(
//                 padding: const EdgeInsets.all(16.0),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       "Tambah Admin",
//                       style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//                     ),
//                     SizedBox(height: 10),
//                     TextField(
//                       controller: _emailController,
//                       decoration: InputDecoration(
//                         labelText: 'Email Admin',
//                         border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
//                       ),
//                     ),
//                     SizedBox(height: 10),
//                     TextField(
//                       controller: _passwordController,
//                       decoration: InputDecoration(
//                         labelText: 'Password',
//                         border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
//                       ),
//                       obscureText: true,
//                     ),
//                     SizedBox(height: 10),
//                     ElevatedButton(
//                       onPressed: _addAdmin,
//                       child: Text('Tambah Admin'),
//                       style: ElevatedButton.styleFrom(
//                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
//                         padding: EdgeInsets.symmetric(vertical: 12),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//             SizedBox(height: 20),

//             // TOMBOL UNTUK MELIHAT FOLDER USER
//             ElevatedButton.icon(
//               onPressed: () {
//                 setState(() {
//                   showFolders = !showFolders;
//                 });
//               },
//               icon: Icon(showFolders ? Icons.folder_open : Icons.folder),
//               label: Text(showFolders ? "Sembunyikan Folder" : "Lihat Semua Folder"),
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: Colors.blue,
//                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
//                 padding: EdgeInsets.symmetric(vertical: 12),
//               ),
//             ),
//             SizedBox(height: 10),

//             // DAFTAR USER JIKA TOMBOL DITEKAN
//             if (showFolders)
//               Expanded(
//                 child: StreamBuilder(
//   stream: _firestore.collection('photos').snapshots(),
//   builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
//     if (!snapshot.hasData) return Center(child: CircularProgressIndicator());

//     return ListView(
//       children: snapshot.data!.docs.map((doc) {
//         String uid = doc.id;
//         Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
//         List<ImageData> imageUrls = List<ImageData>.from(data['imageUrls'] ?? []);

//         return FutureBuilder<DocumentSnapshot>(
//           future: _firestore.collection('users').doc(uid).get(),
//           builder: (context, AsyncSnapshot<DocumentSnapshot> userSnapshot) {
//             if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
//               return SizedBox(); // Jika user tidak ditemukan, sembunyikan
//             }

//             String userName = userSnapshot.data!['email'] ?? 'Tanpa Nama'; // Gantilah dengan field nama jika ada

//             return Card(
//               margin: EdgeInsets.symmetric(vertical: 8),
//               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//               elevation: 3,
//               child: Column(
//                 children: [
//                   ListTile(
//                     leading: userSnapshot.data!['profile'] != null
//     ? CircleAvatar(
//         backgroundImage: NetworkImage(userSnapshot.data!['profile']),
//         radius: 25, // Ukuran foto profil
//       )
//     : CircleAvatar(
//         backgroundColor: Colors.grey[300],
//         child: Icon(Icons.person, color: Colors.white),
//         radius: 25,
//       ),

//                     title: Text('User: $userName', style: TextStyle(fontWeight: FontWeight.bold)),
//                     trailing: Icon(selectedUserId == uid ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down),
//                     onTap: () {
//                       setState(() {
//                         selectedUserId = selectedUserId == uid ? null : uid;
//                       });
//                     },
//                   ),
//                   if (selectedUserId == uid) ...imageUrls.map((image) {
//                     return Padding(
//                       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           ClipRRect(
//                             borderRadius: BorderRadius.circular(10),
//                             child: Image.network(
//                               image['imageUrl'],
//                               width: double.infinity,
//                               height: 200,
//                               fit: BoxFit.cover,
//                             ),
//                           ),
//                           SizedBox(height: 8),
//                           Text(
//                             'Status: ${image['status']}',
//                             style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
//                           ),
//                           SizedBox(height: 8),
//                           Row(
//                             mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                             children: [
//                               ElevatedButton(
//                                 onPressed: () {},
//                                 child: Text("Approve"),
//                                 style: ElevatedButton.styleFrom(
//                                   backgroundColor: Colors.green,
//                                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
//                                 ),
//                               ),
//                               ElevatedButton(
//                                 onPressed: () {},
//                                 child: Text("Reject"),
//                                 style: ElevatedButton.styleFrom(
//                                   backgroundColor: Colors.red,
//                                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
//                                               ),
//                                             ),
//                                           ],
//                                         ),
//                                       ],
//                                     ),
//                                   );
//                                 }).toList(),
//                               ],
//                             ),
//                           );
//                         },
//                       );
//                     }).toList(),
//                   );
//                 },
//               )
//             )
//           ]
//         )
//       )
//     )    ;
//   }
// }
}
