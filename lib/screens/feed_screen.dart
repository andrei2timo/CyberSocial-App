import 'package:flutter/material.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../database_service.dart';

import 'SettingsScreen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dart:convert';
import 'package:http/http.dart' as http;

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final DatabaseService _db = DatabaseService();
  String _filter = "Toate";
  String _currentCity = "Detectare oraș...";
  Position? _myPosition;

  // Animația pentru puls
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Configurare Criptare
  static final key = encrypt.Key.fromUtf8('12345678901234567890123456789012');
  static final iv = encrypt.IV.fromUtf8('1234567890123456');
  final encrypter = encrypt.Encrypter(encrypt.AES(key));

  String _selectedType = "info";

  bool _notificationsEnabled = true;

  // Adaugă metoda asta să o apelezi când te întorci pe ecran
  Future<void> _checkNotificationStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
    });
  }

  @override
  void initState() {
    super.initState();

    _checkNotificationStatus(); // Verificăm la pornire

    // 1. Inițializează controllerul PRIMUL
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    // 2. Inițializează animația folosind controllerul abia creat
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // 3. Apoi restul funcțiilor
    WidgetsBinding.instance.addPostFrameCallback((_) => _determineCity());
    _updateMyPosition();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkNotificationStatus(); // Se apelează de fiecare dată când ecranul revine în focus
  }

  @override
  void dispose() {
    // Foarte important pentru a evita memory leaks
    _pulseController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _updateMyPosition() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );
      if (mounted) {
        setState(() {
          _myPosition = position;
        });
      }
    } catch (e) {
      print("Eroare la obținerea locației: $e");
    }
  }

  void _showReportSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Esențial pentru a preveni suprapunerea
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom:
              MediaQuery.of(context).viewInsets.bottom +
              20, // Ajustare dinamică la tastatură
          top: 20,
          left: 20,
          right: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Raportează Incident",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                hintText: "Detaliază ce se întâmplă...",
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            DropdownButtonFormField<String>(
              value: _selectedType,
              items: [
                "info",
                "pericol",
                "ajutor",
                "hărțuire",
                "iluminat",
              ].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
              onChanged: (v) => setState(() => _selectedType = v!),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                _postMessage();
                Navigator.pop(context);
              },
              child: const Text("Trimite"),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // FUNCȚIE NOUĂ: Transformă coordonatele în nume de oraș
  Future<void> _determineCity() async {
    // Verificăm dacă widget-ul este încă "în viață" înainte de a schimba textul
    if (!mounted) return;
    setState(() => _currentCity = "Se cere permisiunea...");

    // 1. Verifică dacă serviciul GPS e pornit
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!mounted) return;
    if (!serviceEnabled) {
      setState(() => _currentCity = "GPS oprit");
      return;
    }

    // 2. Cere permisiunea dinamic
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (!mounted) return;
      if (permission == LocationPermission.denied) {
        setState(() => _currentCity = "Permisiune refuzată");
        return;
      }
    }

    // Verificare pentru blocare permanentă
    if (permission == LocationPermission.deniedForever) {
      if (!mounted) return;
      setState(() => _currentCity = "Permisiune blocată permanent");
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
        ),
      );

      final url = Uri.parse(
        "https://nominatim.openstreetmap.org/reverse?lat=${position.latitude}&lon=${position.longitude}&format=json&accept-language=ro",
      );

      final response = await http
          .get(
            url,
            headers: {
              "User-Agent":
                  "CyberSocialApp/1.0 (contact@email-ul-tau.ro)", // Pune ceva unic aici
            },
          )
          .timeout(const Duration(seconds: 10)); // Mărim timeout-ul la 10s

      if (!mounted) return; // Foarte important după un 'await'

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final address = data['address'];
        String city =
            address['city'] ??
            address['town'] ??
            address['village'] ??
            "Oraș necunoscut";
        setState(() => _currentCity = city);
      } else {
        print(
          "Eroare Nominatim: ${response.statusCode} - ${response.body}",
        ); // <-- VERIFICĂ TERMINALUL
        setState(() => _currentCity = "Eroare: ${response.statusCode}");
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _currentCity = "Eroare detecție");
    }
  }

  // Helper culori în funcție de tipul incidentului
  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'pericol':
        return Colors.red;
      case 'hărțuire':
        return Colors.purple;
      case 'ajutor':
        return Colors.orange;
      case 'iluminat':
        return Colors.amber[700]!;
      default:
        return Colors.blue;
    }
  }

  Future<void> _refreshLocation() async {
    Position position = await Geolocator.getCurrentPosition();
    if (mounted) {
      setState(() {
        _myPosition = position;
      });
    }
  }

  // Widget pentru Resurse de Suport (Instituții și ONG-uri)
  Widget _buildSupportResources(String type) {
    if (type != 'hărțuire' && type != 'pericol' && type != 'ajutor')
      return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.support_agent, color: Colors.red, size: 20),
              SizedBox(width: 8),
              Text(
                "ASISTENȚĂ ȘI SUPORT",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            "Dacă ești victima unui incident, contactează imediat autoritățile:",
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              ActionChip(
                avatar: const Icon(Icons.phone, size: 16, color: Colors.white),
                backgroundColor: Colors.red[700],
                label: const Text(
                  "112 - URGENȚĂ",
                  style: TextStyle(color: Colors.white),
                ),
                onPressed: () => launchUrl(Uri.parse("tel:112")),
              ),
              if (type == 'hărțuire' || type == 'pericol') ...[
                ActionChip(
                  avatar: const Icon(Icons.call, size: 16),
                  label: const Text("Helpline Violenta: 0800 500 333"),
                  onPressed: () => launchUrl(Uri.parse("tel:0800500333")),
                ),
                ActionChip(
                  avatar: const Icon(Icons.favorite, size: 16),
                  label: const Text("Asociația ANAIS"),
                  onPressed: () =>
                      launchUrl(Uri.parse("https://www.asociatia-anais.ro")),
                ),
                ActionChip(
                  avatar: const Icon(Icons.security, size: 16),
                  label: const Text("Centrul FILIA"),
                  onPressed: () =>
                      launchUrl(Uri.parse("https://centrulfilia.ro")),
                ),
              ],
              if (type == 'hărțuire' || type == 'ajutor') ...[
                ActionChip(
                  avatar: const Icon(Icons.psychology, size: 16),
                  label: const Text("DepreHUB (Psihologic)"),
                  onPressed: () => launchUrl(Uri.parse("https://deprehub.ro")),
                ),
                ActionChip(
                  avatar: const Icon(Icons.chat_bubble_outline, size: 16),
                  label: const Text("Telefonul Copilului: 116 111"),
                  onPressed: () => launchUrl(Uri.parse("tel:116111")),
                ),
              ],
              ActionChip(
                avatar: const Icon(Icons.gavel, size: 16),
                label: const Text("Poliția - Petitii Online"),
                onPressed: () => launchUrl(
                  Uri.parse("https://www.politiaromana.ro/ro/petitii-online"),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Widget Buton Reacție (Ajut, Văzut, Raport)
  Widget _buildReactionButton(
    String postId,
    IconData icon,
    String label,
    String reactionType,
    Color color,
    bool isPressed,
  ) {
    return TextButton.icon(
      onPressed: () => _db.updateReaction(postId, reactionType),
      style: TextButton.styleFrom(
        backgroundColor: isPressed
            ? color.withOpacity(0.2)
            : color.withOpacity(0.05),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      icon: Icon(icon, size: 16, color: color),
      label: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: isPressed ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  // Logica Postare Mesaj
  Future<void> _postMessage() async {
    if (_controller.text.isEmpty) return;

    // 1. Verificare status GPS
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Te rugăm să pornești GPS-ul pentru a raporta!"),
        ),
      );
      return;
    }

    // 2. Verificare permisiune
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      final encrypted = encrypter.encrypt(_controller.text, iv: iv);

      await _db.savePost(
        encrypted.base64,
        FirebaseAuth.instance.currentUser?.email ?? 'Anonim',
        GeoPoint(position.latitude, position.longitude),
        _selectedType,
      );

      _controller.clear();
      setState(() => _selectedType = "info");

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Raportat cu succes!")));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Eroare la trimitere: $e")));
    }
  }

  Future<void> _sendSOS() async {
    try {
      // 0. Verificăm dacă GPS-ul este pornit
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Te rugăm să pornești GPS-ul pentru a trimite SOS!"),
          ),
        );
        return;
      }

      // 1. Obține lista de contacte salvată ca JSON
      final prefs = await SharedPreferences.getInstance();
      final String? encoded = prefs.getString('sos_contacts');

      if (encoded == null || encoded.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Nu ai setat contacte de urgență!")),
        );
        return;
      }

      // 2. Extrage numerele de telefon din JSON
      List<dynamic> list = jsonDecode(encoded);
      String phoneNumbers = list.map((c) => c['phone']).join(",");

      // 3. Obține locația cu precizie mare
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      // 4. Creează link-ul corect (Atenție la simbolurile $ înainte de acolade!)
      String googleMapsUrl =
          "https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}";

      String mesajSOS =
          "SOS: Sunt în pericol! Locația mea este: $googleMapsUrl";

      // 5. Trimite alerta în baza de date (Firebase)
      final encryptedSOS = encrypter.encrypt(
        "SUNT ÎN PERICOL! AM NEVOIE DE AJUTOR LA: $googleMapsUrl",
        iv: iv,
      );
      await _db.savePost(
        encryptedSOS.base64,
        FirebaseAuth.instance.currentUser?.email ?? 'Anonim',
        GeoPoint(position.latitude, position.longitude),
        "pericol",
      );

      // 6. Deschide aplicația de SMS
      final Uri smsUri = Uri(
        scheme: 'sms',
        path: phoneNumbers,
        queryParameters: {'body': mesajSOS},
      );

      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri);
      } else {
        throw 'Nu s-a putut deschide aplicația de SMS';
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Eroare SOS: ${e.toString()}")));
    }
  }

  String _getDecryptedMessage(String encryptedBase64) {
    try {
      return encrypter.decrypt64(encryptedBase64, iv: iv);
    } catch (e) {
      return "Mesaj indisponibil (Eroare decriptare).";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("🛡️ CyberSocial Feed"),
        backgroundColor: Colors.indigo[900],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: "Logout",
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),

      // Butoane flotante pentru acțiuni rapide
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(
          bottom: 20.0,
        ), // Adaugă spațiu față de bara de jos
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // AICI pui codul cu animația:
            ScaleTransition(
              scale: _pulseAnimation,
              child: FloatingActionButton.extended(
                heroTag: "sos",
                backgroundColor: Colors.red,
                onPressed: _sendSOS,
                icon: const Icon(Icons.emergency, color: Colors.white),
                label: const Text(
                  "SOS",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // BUTON RAPORTEAZĂ
            FloatingActionButton.extended(
              heroTag: "report",
              backgroundColor: Colors.indigo[900],
              onPressed: _showReportSheet,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                "Raportează",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),

      body: Column(
        children: [
          // 1. FILTRARE
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children:
                  ["Toate", "Pericol", "Hărțuire", "Ajutor", "Iluminat", "Info"]
                      .map(
                        (f) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(f),
                            selected: _filter == f,
                            selectedColor: Colors.indigo[100],
                            onSelected: (val) => setState(() => _filter = f),
                          ),
                        ),
                      )
                      .toList(),
            ),
          ),

          // 2. LOCAȚIE
          InkWell(
            onTap: _determineCity,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.location_on, size: 16, color: Colors.indigo),
                  const SizedBox(width: 5),
                  Text(
                    "Oraș: $_currentCity (Refresh)",
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. FEED (Aici tot spațiul este acum dedicat postărilor)
          Expanded(
            child: _notificationsEnabled
                ? StreamBuilder<QuerySnapshot>(
                    stream: _db.getPostsStream(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData)
                        return const Center(child: CircularProgressIndicator());

                      if (_myPosition == null) {
                        return const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 10),
                              Text("Se determină locația..."),
                            ],
                          ),
                        );
                      }

                      var docs = snapshot.data!.docs.where((doc) {
                        var data = doc.data() as Map<String, dynamic>;
                        var location = data['location'] as GeoPoint?;

                        double dist = (location != null && _myPosition != null)
                            ? Geolocator.distanceBetween(
                                    _myPosition!.latitude,
                                    _myPosition!.longitude,
                                    location.latitude,
                                    location.longitude,
                                  ) /
                                  1000
                            : 0;

                        bool isNearby = dist <= 30.0;
                        bool matchesType =
                            _filter == "Toate" ||
                            data['type'] == _filter.toLowerCase();
                        return isNearby && matchesType;
                      }).toList();

                      if (docs.isEmpty)
                        return const Center(
                          child: Text("Niciun incident în zonă."),
                        );

                      return ListView.builder(
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          var data = docs[index].data() as Map<String, dynamic>;
                          String type = data['type'] ?? 'info';
                          String userEmail =
                              FirebaseAuth.instance.currentUser?.email ?? '';
                          var reactions = data['reactions'] as Map? ?? {};
                          int rCount = reactions['raport'] ?? 0;
                          bool isHotspot = rCount > 5;

                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: isHotspot
                                    ? Colors.red
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border(
                                  left: BorderSide(
                                    color: _getTypeColor(type),
                                    width: 6,
                                  ),
                                ),
                              ),
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        type.toUpperCase(),
                                        style: TextStyle(
                                          color: _getTypeColor(type),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        "Utilizator #${data['sender']?.hashCode.toString().substring(0, 4) ?? '0000'}",
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _getDecryptedMessage(data['message']),
                                    style: const TextStyle(fontSize: 15),
                                  ),
                                  _buildSupportResources(type),
                                  const Divider(height: 24),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceAround,
                                    children: [
                                      _buildReactionButton(
                                        docs[index].id,
                                        Icons.check_circle,
                                        "Ajut (${reactions['ajutor'] ?? 0})",
                                        "ajutor",
                                        Colors.green,
                                        (data['votedBy_ajutor'] as List?)
                                                ?.contains(userEmail) ??
                                            false,
                                      ),
                                      _buildReactionButton(
                                        docs[index].id,
                                        Icons.visibility,
                                        "Văzut (${reactions['vazut'] ?? 0})",
                                        "vazut",
                                        Colors.blue,
                                        (data['votedBy_vazut'] as List?)
                                                ?.contains(userEmail) ??
                                            false,
                                      ),
                                      _buildReactionButton(
                                        docs[index].id,
                                        Icons.flag,
                                        "Raport ($rCount)",
                                        "raport",
                                        Colors.red,
                                        (data['votedBy_raport'] as List?)
                                                ?.contains(userEmail) ??
                                            false,
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
                  )
                : const Center(child: Text("Notificările sunt oprite.")),
          ),
        ],
      ),
    );
  }
}
