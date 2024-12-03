import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:machat/screens/UserListScreen.dart';
import 'package:machat/screens/auth/login_screen.dart';
import 'package:machat/screens/groupchat.dart';
import 'package:machat/screens/chat_screen.dart';
import 'package:machat/screens/profileupdate.dart';

class GroupHomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<GroupHomePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    final String currentUserId = _auth.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Group Chats'),
        actions: [
          IconButton(
            icon: const Icon(Icons.group_add),
            onPressed: _showUserList,
          ),
        ],
      ),
      body: Column(
        children: [
          // Group Chats Stream
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('group')
                  .where('users', arrayContains: currentUserId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(child: Text('No group chats found.'));
                }

                final groupDocs = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: groupDocs.length,
                  itemBuilder: (context, index) {
                    final groupData = groupDocs[index];
                    final groupId = groupData.id;
                    final groupName = groupData['name'] ?? 'Unnamed Group';
                    final users = List<String>.from(groupData['users']);
                    final profilePhotoId = groupData['profilePhotoId'];

                    // Fetch user names and group photo for each group
                    return FutureBuilder<List<String>>(
                      future: _getUserNames(users),
                      builder: (context, userNamesSnapshot) {
                        if (userNamesSnapshot.connectionState ==
                            ConnectionState.waiting) {
                          return ListTile(
                            title: Center(child: CircularProgressIndicator()),
                          );
                        }

                        if (userNamesSnapshot.hasError) {
                          return ListTile(
                            title: Text('Error loading user names'),
                          );
                        }

                        if (!userNamesSnapshot.hasData ||
                            userNamesSnapshot.data!.isEmpty) {
                          return ListTile(
                            title: Text('No members found'),
                          );
                        }

                        final memberNames = userNamesSnapshot.data!;

                        return FutureBuilder<DocumentSnapshot>(
                          future: _firestore
                              .collection('profilephoto')
                              .doc(profilePhotoId)
                              .get(),
                          builder: (context, photoSnapshot) {
                            final groupPhotoUrl = photoSnapshot.hasData &&
                                    photoSnapshot.data!.exists
                                ? photoSnapshot.data!['imageUrl']
                                : null;

                            return ListTile(
                              leading: groupPhotoUrl != null
                                  ? CircleAvatar(
                                      backgroundImage:
                                          NetworkImage(groupPhotoUrl),
                                      radius: 30)
                                  : CircleAvatar(
                                      child: Icon(Icons.group),
                                      backgroundColor: Colors.grey[300],
                                    ),
                              title: Text(
                                groupName,
                                style: const TextStyle(
                                    fontSize: 22, fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(' ${memberNames.join(', ')}'),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => GroupChatScreen(
                                      groupId: groupId,
                                      name: groupName,
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Fetch user names from user IDs
  Future<List<String>> _getUserNames(List<String> userIds) async {
    List<String> userNames = [];

    for (var userId in userIds) {
      final userDoc = await _firestore.collection('Users').doc(userId).get();
      if (userDoc.exists) {
        userNames.add(userDoc['empname']);
      }
    }

    return userNames;
  }

  void _showUserList() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserListScreen(),
      ),
    );
  }
}
