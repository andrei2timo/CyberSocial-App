import 'package:flutter/material.dart'; // Importă asta pentru widget-uri
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

final Map<String, dynamic> romaniaCitiesData = {
  "galati": {
    "name": "Galați",
    "contacts": [
      {"label": "Primăria Galați", "value": "https://www.primariagalati.ro"},
      {"label": "Poliția Locală", "value": "tel:0236460000"},
      {
        "label": "Spitalul Județean",
        "value": "https://www.spitaluljudeteangalati.ro",
      },
      {"label": "Asociația ANAIS", "value": "https://www.asociatia-anais.ro"},
    ],
  },
  "iasi": {
    "name": "Iași",
    "contacts": [
      {"label": "Primăria Iași", "value": "https://www.primaria-iasi.ro"},
      {"label": "Poliția Locală", "value": "tel:0232232095"},
      {
        "label": "Spitalul Sf. Spiridon",
        "value": "https://www.spitalspiridon.ro",
      },
      {"label": "Centrul FILIA", "value": "https://centrulfilia.ro"},
    ],
  },
  "bucuresti": {
    "name": "București",
    "contacts": [
      {"label": "Primăria Capitalei", "value": "https://pmb.ro"},
      {"label": "Poliția Locală", "value": "tel:0219752"},
      {
        "label": "Spitalul Floreasca",
        "value": "https://www.spitalfloreasca.ro",
      },
      {"label": "DepreHUB", "value": "https://deprehub.ro"},
    ],
  },
  "clujnapoca": {
    "name": "Cluj-Napoca",
    "contacts": [
      {"label": "Primăria Cluj", "value": "https://primariaclujnapoca.ro"},
      {"label": "Poliția Locală", "value": "tel:0264955"},
      {"label": "Spitalul Clinic Județean", "value": "https://scjucluj.ro"},
    ],
  },
  "timisoara": {
    "name": "Timișoara",
    "contacts": [
      {"label": "Primăria Timișoara", "value": "https://primariatm.ro"},
      {"label": "Poliția Locală", "value": "tel:0256968"},
      {"label": "Spitalul Județean Timișoara", "value": "https://hosptm.ro"},
    ],
  },
  "brasov": {
    "name": "Brașov",
    "contacts": [
      {"label": "Primăria Brașov", "value": "https://brasovcity.ro"},
      {"label": "Poliția Locală", "value": "tel:0268954"},
      {
        "label": "Spitalul Județean Brașov",
        "value": "https://spitaljudeteanbrasov.ro",
      },
    ],
  },
  "constanta": {
    "name": "Constanța",
    "contacts": [
      {"label": "Primăria Constanța", "value": "https://primaria-constanta.ro"},
      {"label": "Poliția Locală", "value": "tel:0241484205"},
      {
        "label": "Spitalul Județean Constanța",
        "value": "https://spitalconstantanoua.ro",
      },
    ],
  },
  "craiova": {
    "name": "Craiova",
    "contacts": [
      {"label": "Primăria Craiova", "value": "https://www.primariacraiova.ro"},
      {"label": "Poliția Locală", "value": "tel:0251984"},
      {"label": "Spitalul Județean Craiova", "value": "https://scjuc.ro"},
    ],
  },
  "arad": {
    "name": "Arad",
    "contacts": [
      {"label": "Primăria Arad", "value": "https://www.primariaarad.ro"},
      {"label": "Poliția Locală", "value": "tel:0257939"},
      {"label": "Spitalul Județean Arad", "value": "https://spitalarad.ro"},
    ],
  },
  "bacau": {
    "name": "Bacău",
    "contacts": [
      {"label": "Primăria Bacău", "value": "https://municipiulbacau.ro"},
      {"label": "Poliția Locală", "value": "tel:0234984"},
      {
        "label": "Spitalul Județean Bacău",
        "value": "https://spitaluljudeteanbacau.ro",
      },
    ],
  },
  "sibiu": {
    "name": "Sibiu",
    "contacts": [
      {"label": "Primăria Sibiu", "value": "https://sibiu.ro"},
      {"label": "Poliția Locală", "value": "tel:0269208961"},
      {"label": "Spitalul Județean Sibiu", "value": "https://scjs.ro"},
    ],
  },
  "oradea": {
    "name": "Oradea",
    "contacts": [
      {"label": "Primăria Oradea", "value": "https://oradea.ro"},
      {"label": "Poliția Locală", "value": "tel:0259969"},
      {
        "label": "Spitalul Județean Oradea",
        "value": "https://www.spitaloradea.ro",
      },
    ],
  },
  "pitesti": {
    "name": "Pitești",
    "contacts": [
      {"label": "Primăria Pitești", "value": "https://www.primariapitesti.ro"},
      {"label": "Poliția Locală", "value": "tel:0248210103"},
      {"label": "Spitalul Județean Argeș", "value": "https://sjupitesti.ro"},
    ],
  },
  "ploiesti": {
    "name": "Ploiești",
    "contacts": [
      {"label": "Primăria Ploiești", "value": "https://www.ploiesti.ro"},
      {"label": "Poliția Locală", "value": "tel:0244954"},
      {
        "label": "Spitalul Județean Prahova",
        "value": "https://spitaluljudeteanploiesti.ro",
      },
    ],
  },
};

// 2. Aici este clasa care va afișa butonul
class AdminPage extends StatelessWidget {
  const AdminPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Șterge complet acel 'if' care verifică email-ul.
    // Lasă doar pagina să se deschidă direct:
    return Scaffold(
      appBar: AppBar(title: const Text("Panou Admin")),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            await uploadAllCities();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Datele au fost încărcate!")),
            );
          },
          child: const Text("Încarcă orașele în Firebase"),
        ),
      ),
    );
  }

  // 3. Funcția de import
  Future<void> uploadAllCities() async {
    // Ștergem tot ce ține de 'user' și 'if (user == null)'
    final db = FirebaseFirestore.instance;

    for (var entry in romaniaCitiesData.entries) {
      try {
        await db
            .collection('local_resources')
            .doc(entry.key)
            .set(entry.value, SetOptions(merge: true));
        print("Am încărcat: ${entry.key}");
      } catch (e) {
        print("Eroare la ${entry.key}: $e");
      }
    }
    print("Operațiunea s-a terminat!");
  }
}
