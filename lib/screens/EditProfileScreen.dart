import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditProfileScreen extends StatefulWidget {
  @override
  _EditProfileScreenState createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nameController = TextEditingController();
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentProfile();
  }

  Future<void> _loadCurrentProfile() async {
    var user = _auth.currentUser;
    if (user != null) {
      var doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        setState(() {
          _nameController.text = doc.data()?['name'] ?? '';
        });
      }
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isLoading = true);
    try {
      await _firestore.collection('users').doc(_auth.currentUser!.uid).set({
        'name': _nameController.text,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Eroare: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    final isEmailProvider = user?.providerData.first.providerId == 'password';

    return Scaffold(
      appBar: AppBar(title: const Text("Profil și Securitate")),
      body: ListView( // Folosim ListView pentru a preveni overflow-ul
        padding: const EdgeInsets.all(16.0),
        children: [
          const Text("Detalii Cont", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ListTile(leading: const Icon(Icons.email), title: const Text("Email"), subtitle: Text(user?.email ?? "Nespecificat")),
          ListTile(
            leading: const Icon(Icons.badge), 
            title: const Text("Autentificare"), 
            subtitle: Text(isEmailProvider ? 'Email și Parolă' : 'Google'),
          ),
          const Divider(),
          const SizedBox(height: 10),
          TextField(controller: _nameController, decoration: const InputDecoration(labelText: "Nume Afișat", border: OutlineInputBorder(), prefixIcon: Icon(Icons.person))),
          const SizedBox(height: 20),
          _isLoading ? const Center(child: CircularProgressIndicator()) : ElevatedButton(onPressed: _saveProfile, child: const Text("Salvează Modificările")),
          
        ],
      ),
    );
  }
}