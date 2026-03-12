import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'EditProfileScreen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EmergencyContact {
  String name;
  String phone;
  String relation;

  EmergencyContact({
    required this.name,
    required this.phone,
    required this.relation,
  });

  Map<String, dynamic> toMap() => {
    'name': name,
    'phone': phone,
    'relation': relation,
  };
  factory EmergencyContact.fromMap(Map<String, dynamic> map) =>
      EmergencyContact(
        name: map['name'],
        phone: map['phone'],
        relation: map['relation'],
      );
}

class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  List<EmergencyContact> contacts = [];

  @override
  void initState() {
    super.initState();
    _loadContacts();
    _loadSettings(); // Adaugă linia asta aici!
  }

  // 1. Variabilă de stare pentru notificări
  bool _notificationsEnabled = true;

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    // Citim valoarea salvată. Dacă nu există (prima utilizare), default este true.
    final bool savedValue = prefs.getBool('notifications_enabled') ?? true;

    // Verificăm dacă widget-ul este încă montat înainte de setState
    if (mounted) {
      setState(() {
        _notificationsEnabled = savedValue;
      });
    }
  }

  // 3. Salvează starea notificărilor
  Future<void> _toggleNotifications(bool value) async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Salvarea stării local
    await prefs.setBool('notifications_enabled', value);
    setState(() {
      _notificationsEnabled = value;
    });

    // 2. Comunicarea cu Firebase pentru abonare/dezabonare
    // Topic-ul trebuie să fie același cu cel de pe care trimiți alerte
    try {
      if (value) {
        await FirebaseMessaging.instance.subscribeToTopic("pericole_locale");
        print("Te-ai abonat la notificări.");
      } else {
        await FirebaseMessaging.instance.unsubscribeFromTopic(
          "pericole_locale",
        );
        print("Te-ai dezabonat de la notificări.");
      }
    } catch (e) {
      print("Eroare Firebase: $e");
    }
  }

  Future<void> _loadContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final String? encoded = prefs.getString('sos_contacts');
    if (encoded != null) {
      setState(() {
        contacts = (jsonDecode(encoded) as List)
            .map((i) => EmergencyContact.fromMap(i))
            .toList();
      });
    }
  }

  Future<void> _saveContacts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'sos_contacts',
      jsonEncode(contacts.map((c) => c.toMap()).toList()),
    );
  }

  // Adaugă această metodă în _SettingsScreenState
  void _showContactDialog({int? index}) {
    final nameCtrl = TextEditingController(
      text: index != null ? contacts[index].name : '',
    );
    final phoneCtrl = TextEditingController(
      text: index != null ? contacts[index].phone : '',
    );

    final List<String> relations = [
      'Familie',
      'Prieten',
      'Partener',
      'Coleg',
      'Altul',
    ];
    String initialRelation =
        (index != null && relations.contains(contacts[index].relation))
        ? contacts[index].relation
        : relations.first;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            index == null ? "Adaugă Contact" : "Editează Contact",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Câmpuri stilizate
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: "Nume",
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: phoneCtrl,
                decoration: InputDecoration(
                  labelText: "Telefon",
                  prefixIcon: const Icon(Icons.phone_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: initialRelation,
                decoration: InputDecoration(
                  labelText: "Relație",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.family_restroom),
                ),
                items: relations
                    .map(
                      (rel) => DropdownMenuItem(value: rel, child: Text(rel)),
                    )
                    .toList(),
                onChanged: (val) =>
                    setDialogState(() => initialRelation = val!),
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          actions: [
            // Buton Ștergere (Apare doar la editare)
            if (index != null)
              TextButton.icon(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                label: const Text(
                  "Șterge",
                  style: TextStyle(color: Colors.red),
                ),
                onPressed: () {
                  setState(() => contacts.removeAt(index));
                  _saveContacts();
                  Navigator.pop(ctx);
                },
              ),
            const Spacer(), // Împinge butoanele de acțiune spre margini
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Anulează"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                if (nameCtrl.text.isNotEmpty && phoneCtrl.text.isNotEmpty) {
                  setState(() {
                    if (index == null) {
                      contacts.add(
                        EmergencyContact(
                          name: nameCtrl.text,
                          phone: phoneCtrl.text,
                          relation: initialRelation,
                        ),
                      );
                    } else {
                      contacts[index] = EmergencyContact(
                        name: nameCtrl.text,
                        phone: phoneCtrl.text,
                        relation: initialRelation,
                      );
                    }
                  });
                  _saveContacts();
                  Navigator.pop(ctx);
                }
              },
              child: const Text("Salvează"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Setări")),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              "Profil",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.indigo,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text("Editează Profilul"),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => EditProfileScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.lock),
            title: const Text("Securitate & Autentificare"),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SecurityScreen()),
              );
            },
          ),

          const Divider(),

          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              "Urgență",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.indigo,
              ),
            ),
          ),
          // Aici pui lista ta de contacte, eventual ca un ExpansionTile
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Contacte de Urgență",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo,
                    fontSize: 16,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle, color: Colors.indigo),
                  onPressed: () =>
                      _showContactDialog(), // Aici era eroarea: apelează metoda corectă
                ),
              ],
            ),
          ),
          ...contacts.asMap().entries.map((entry) {
            int index = entry.key; // Preluăm indexul curent
            EmergencyContact c = entry.value;

            return Dismissible(
              // Folosim o cheie unică bazată pe index, mult mai sigur
              key: ValueKey('contact_$index'),
              background: Container(
                color: Colors.red,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                child: const Icon(Icons.delete, color: Colors.white),
              ),
              onDismissed: (direction) {
                setState(() {
                  contacts.removeAt(index); // Ștergem sigur prin index
                });
                _saveContacts();
              },
              child: Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(c.name),
                  subtitle: Text("${c.relation} • ${c.phone}"),
                  // Am păstrat iconița de telefon, dar am adăugat un buton de editare
                  trailing: IconButton(
                    icon: const Icon(Icons.edit, color: Colors.indigo),
                    onPressed: () => _showContactDialog(index: index),
                  ),
                ),
              ),
            );
          }).toList(),

          const Divider(),

          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              "Preferințe Feed",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.indigo,
              ),
            ),
          ),
          SwitchListTile(
            title: const Text("Notificări pentru pericole locale"),
            subtitle: const Text(
              "Primește alerte în timp real despre pericole din zona ta",
            ),
            secondary: Icon(
              _notificationsEnabled
                  ? Icons.notifications_active
                  : Icons.notifications_off,
              color: _notificationsEnabled ? Colors.indigo : Colors.grey,
            ),
            value: _notificationsEnabled,
            activeColor: Colors.indigo,
            onChanged: (val) => _toggleNotifications(val),
          ),
        ],
      ),
    );
  }
}

class SecurityScreen extends StatefulWidget {
  @override
  _SecurityScreenState createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  final _auth = FirebaseAuth.instance;

  void _showChangePasswordDialog() {
    final oldPassCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Schimbă Parola"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: oldPassCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: "Parola Veche"),
            ),
            TextField(
              controller: newPassCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: "Parola Nouă"),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Anulează"),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                AuthCredential credential = EmailAuthProvider.credential(
                  email: _auth.currentUser!.email!,
                  password: oldPassCtrl.text,
                );
                await _auth.currentUser!.reauthenticateWithCredential(
                  credential,
                );
                await _auth.currentUser!.updatePassword(newPassCtrl.text);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Parolă actualizată!")),
                );
              } catch (e) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text("Eroare: $e")));
              }
            },
            child: const Text("Confirmă"),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount() async {
    // 1. Cerem confirmarea și parola
    final passwordCtrl = TextEditingController();
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Șterge contul definitiv?"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Introdu parola pentru a confirma ștergerea:"),
            TextField(controller: passwordCtrl, obscureText: true),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Anulează"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              "Confirmă",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // 2. Re-autentificare
        User? user = _auth.currentUser;
        AuthCredential credential = EmailAuthProvider.credential(
          email: user!.email!,
          password: passwordCtrl.text,
        );
        await user.reauthenticateWithCredential(credential);

        // 3. Acum ștergem
        await user.delete();

        // Navigare la Login
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => LoginScreen()),
          (route) => false,
        );
      } on FirebaseAuthException catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Eroare: ${e.message}")));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("A apărut o eroare neașteptată.")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    final isEmailProvider = user?.providerData.first.providerId == 'password';

    return Scaffold(
      appBar: AppBar(title: const Text("Securitate")),
      body: ListView(
        children: [
          ListTile(
            title: const Text("Email Cont"),
            subtitle: Text(user?.email ?? ""),
          ),
          if (isEmailProvider)
            ListTile(
              leading: const Icon(Icons.lock_reset),
              title: const Text("Schimbă Parola"),
              onTap: _showChangePasswordDialog,
            ),
          const Divider(),
          // Deconectarea a fost eliminată de aici
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text(
              "Șterge contul definitiv",
              style: TextStyle(color: Colors.red),
            ),
            onTap: _deleteAccount,
          ),
        ],
      ),
    );
  }
}
