import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';


class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isRegistering = false;

  Future<void> _handleAuth() async {
    try {
      if (_isRegistering) {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        _showSnackBar("Cont creat cu succes!");
      } else {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        _showSnackBar("Logare reușită!");
      }
    } on FirebaseAuthException catch (e) {
      _showSnackBar("Eroare: ${e.message}");
    } catch (e) {
      _showSnackBar("A apărut o eroare neașteptată.");
    }
  }

  Future<void> _signInWithGoogle() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) return;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);
      _showSnackBar("Logare Google reușită!");
    } catch (e) {
      _showSnackBar("Eroare Google: ${e.toString()}");
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.shield_rounded,
                size: 80,
                color: Colors.blueAccent,
              ),
              const SizedBox(height: 16),
              Text(
                _isRegistering ? "Creează cont" : "Bine ai revenit",
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Parolă',
                  prefixIcon: Icon(Icons.lock),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _handleAuth,
                  child: Text(_isRegistering ? "Înregistrează-te" : "Logare"),
                ),
              ),
              TextButton(
                onPressed: () =>
                    setState(() => _isRegistering = !_isRegistering),
                child: Text(
                  _isRegistering
                      ? "Ai deja cont? Loghează-te"
                      : "Nu ai cont? Creează unul",
                ),
              ),
              const Divider(height: 40),
              // Modifică OutlinedButton.icon din build:
              OutlinedButton.icon(
                onPressed: _signInWithGoogle,
                // Folosim iconița oficială de la FontAwesome
                icon: const FaIcon(
                  FontAwesomeIcons.google,
                  color: Colors.red,
                  size: 20,
                ),
                label: const Text("Logare cu Google"),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 24,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
