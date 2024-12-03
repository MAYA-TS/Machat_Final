// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:machat/model/usermodel.dart';

// class FirestoreService {
//   final FirebaseFirestore _db = FirebaseFirestore.instance;

//   // Add user to Firestore
//   Future<void> addUser(UserModel user, String uid) async {
//     try {
//       await _db.collection('Users').doc(uid).set(user.toMap());
//     } catch (e) {
//       throw e; // or handle error as needed
//     }
//   }

//   // Fetch the group chats where the user is a member
//   Future<List<DocumentSnapshot>> getGroupChats(String currentUserId) async {
//     try {
//       QuerySnapshot querySnapshot = await _db
//           .collection('groups') // 'groups' collection
//           .where('users',
//               arrayContains: currentUserId) // Ensure 'members' exists
//           .get();

//       return querySnapshot.docs;
//     } catch (e) {
//       throw e; // or handle error as needed
//     }
//   }
// }

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:machat/model/usermodel.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Add user to Firestore
  Future<void> addUser(UserModel user, String uid) async {
    try {
      await _db.collection('Users').doc(uid).set(user.toMap());
    } catch (e) {
      throw e; // or handle error as needed
    }
  }

  // Fetch the profile photo URL for a given user
  Future<String?> getProfilePictureUrl(String userId) async {
    try {
      DocumentSnapshot snapshot =
          await _db.collection('profilephoto').doc(userId).get();

      if (snapshot.exists) {
        // If the document exists, return the profile picture URL
        return snapshot['profilePictureUrl'];
      } else {
        // If no document exists, return null
        return null;
      }
    } catch (e) {
      print('Error fetching profile photo: $e');
      return null;
    }
  }

  // Fetch the group chats where the user is a member
  Future<List<DocumentSnapshot>> getGroupChats(String currentUserId) async {
    try {
      QuerySnapshot querySnapshot = await _db
          .collection('groups') // 'groups' collection
          .where('users',
              arrayContains: currentUserId) // Ensure 'members' exists
          .get();

      return querySnapshot.docs;
    } catch (e) {
      throw e; // or handle error as needed
    }
  }
}
