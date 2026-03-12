import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Aceasta este sursa de date pentru StreamBuilder-ul din FeedScreen
  Stream<QuerySnapshot> getPostsStream() {
    return _db
        .collection('posts')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  Future<void> updateReaction(String postId, String reactionType) async {
    String userId = FirebaseAuth.instance.currentUser?.uid ?? 'Anonim';
    DocumentReference postRef = FirebaseFirestore.instance
        .collection('posts')
        .doc(postId);

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      DocumentSnapshot snapshot = await transaction.get(postRef);
      if (!snapshot.exists) return;

      Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
      List votedBy = data['votedBy_$reactionType'] ?? [];

      // Prevenire Spam: Dacă a votat deja, nu facem nimic
      if (votedBy.contains(userId)) return;

      transaction.update(postRef, {
        'reactions.$reactionType': FieldValue.increment(1),
        'votedBy_$reactionType': FieldValue.arrayUnion([userId]),
      });
    });
  }

  Stream<QuerySnapshot> getPostsByCity(String city) {
    return FirebaseFirestore.instance
        .collection('posts')
        .where('city', isEqualTo: city)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // Am redenumit 'content' în 'message' pentru a se potrivi cu FeedScreen
  Future<void> savePost(
    String encryptedContent,
    String senderEmail,
    GeoPoint? location,
    String type,
  ) async {
    try {
      await _db.collection('posts').add({
        'message': encryptedContent,
        'sender': senderEmail,
        'location': location, // Salvează coordonatele GPS
        'type': type, // Salvează natura incidentului (ex: 'pericol', 'info')
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print("Eroare la salvare: $e");
    }
  }
}
