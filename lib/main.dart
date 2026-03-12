import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart'; // <--- Avem nevoie de kIsWeb

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print("Mesaj primit în fundal: ${message.notification?.title}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    print("Eroare critică Firebase: $e");
    // Poți afișa un ecran de eroare aici dacă Firebase e esențial
  }

  await _setupNotifications();
  runApp(const CyberSocialApp());
}

// Funcție separată pentru a nu bloca pornirea aplicației
Future<void> _setupNotifications() async {
  FirebaseMessaging messaging = FirebaseMessaging.instance;

  try {
    // Cerem permisiunea
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      // ATENȚIE: subscribeToTopic NU funcționează pe WEB
      if (!kIsWeb) {
        await messaging.subscribeToTopic("alerts");
        print('Utilizator abonat la topic pe Mobile.');
      } else {
        print('Notificările sunt active pe Web (fără topic).');
      }
    }

    // Setăm handler-ul doar dacă nu suntem pe web (sau dacă e configurat worker)
    if (!kIsWeb) {
      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );
    }
  } catch (e) {
    print("Eroare la configurarea notificărilor: $e");
    // Aplicația va continua să ruleze chiar dacă notificările eșuează
  }
  // Adaugă asta în _setupNotifications(), după blocul try-catch:
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print('Mesaj primit în prim-plan: ${message.notification?.title}');

    // Opțional: Poți arăta un Snackbar dacă utilizatorul e în aplicație
    // ScaffoldMessenger.of(context).showSnackBar(...);
    // (Atenție: pentru context ai nevoie de o cheie globală - GlobalKey)
  });
}

class CyberSocialApp extends StatelessWidget {
  const CyberSocialApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CyberSocial',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasData) {
            return const HomeScreen(); // Utilizator logat
          }
          return const LoginScreen(); // Utilizator nelogat
        },
      ),
    );
  }
}
