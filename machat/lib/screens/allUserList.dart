import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:machat/screens/singleChat.dart';

class Userlist extends StatefulWidget {
  const Userlist({super.key});

  @override
  State<Userlist> createState() => _UserlistState();
}

class _UserlistState extends State<Userlist> {
  TextEditingController searchController = TextEditingController();
  String searchQuery = '';

  Future<String> _fetchProfilePicture(String userId) async {
    try {
      DocumentSnapshot profileDoc = await FirebaseFirestore.instance
          .collection('profilephoto')
          .doc(userId) // Use the user ID as the document ID
          .get();

      if (profileDoc.exists) {
        return profileDoc['profilePictureUrl'] ?? '';
      } else {
        return ''; // Return empty if no profile picture
      }
    } catch (e) {
      print('Error fetching profile picture: $e');
      return ''; // Return empty string in case of error
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get the current user (ensure the user is logged in)
    User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      // If the user is not logged in, show a message or redirect
      return Scaffold(
        appBar: AppBar(title: const Text("User List")),
        body: const Center(child: Text("Please log in to view users.")),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("User List")),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: searchController,
              onChanged: (query) {
                setState(() {
                  searchQuery = query;
                });
              },
              decoration: InputDecoration(
                hintText: 'Search user...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
            ),
          ),
          // User List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream:
                  FirebaseFirestore.instance.collection('Users').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Center(child: Text('Error fetching data'));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No users available.'));
                }

                // Filter users based on search query
                var filteredDocs = snapshot.data!.docs.where((doc) {
                  return doc.id != currentUser.uid &&
                      ((doc['empname'] as String)
                              .toLowerCase()
                              .contains(searchQuery.toLowerCase()) ||
                          (doc['empcode'] as String)
                              .toLowerCase()
                              .contains(searchQuery.toLowerCase()));
                }).toList();

                // Sort users alphabetically by empname
                filteredDocs.sort((a, b) {
                  return a['empname']
                      .toString()
                      .compareTo(b['empname'].toString());
                });

                return ListView.builder(
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    var doc = filteredDocs[index];
                    var empCode = doc['empcode'] ?? '';
                    var empName = doc['empname'] ?? '';
                    var userId = doc.id;

                    return FutureBuilder<String>(
                      future: _fetchProfilePicture(userId),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return ListTile(
                            leading: CircleAvatar(
                              radius: 24,
                              backgroundColor: Colors.grey,
                              child: const CircularProgressIndicator(),
                            ),
                            title: Text(empName),
                            subtitle: Text(empCode),
                          );
                        }

                        String profilePictureUrl = snapshot.data ?? '';

                        return ListTile(
                          leading: CircleAvatar(
                            radius: 24,
                            backgroundImage: profilePictureUrl.isNotEmpty
                                ? NetworkImage(profilePictureUrl)
                                : null,
                            child: profilePictureUrl.isEmpty
                                ? const Icon(Icons.person, color: Colors.white)
                                : null,
                          ),
                          title: Text(
                            empName,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          subtitle: Text(
                            empCode,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.black54,
                            ),
                          ),
                          onTap: () async {
                            final chatRef =
                                FirebaseFirestore.instance.collection('chats');
                            final userID = currentUser.uid;
                            final userName = currentUser.displayName ?? '';

                            final otherUserID = doc.id;
                            final otherUserName = doc['empname'] ?? '';

                            // Check for an existing chat with this user
                            QuerySnapshot existingChat = await chatRef
                                .where('participants', arrayContains: userID)
                                .get();

                            String chatID = '';
                            bool chatExists = false;

                            for (var chatDoc in existingChat.docs) {
                              var participants =
                                  List<String>.from(chatDoc['participants']);
                              if (participants.contains(otherUserID)) {
                                chatID = chatDoc.id;
                                chatExists = true;
                                break;
                              }
                            }

                            // If no existing chat, create a new chat
                            if (!chatExists) {
                              DocumentReference newChatDoc = await chatRef.add({
                                'participants': [userID, otherUserID],
                                'lastMessage': '',
                                'lastMessageTime': FieldValue.serverTimestamp(),
                                'lastMessageAt': FieldValue.serverTimestamp(),
                                'hasUnreadMessages': false,
                                'last_message_seen_by': [],
                              });
                              chatID = newChatDoc.id;
                            }

                            // Navigate to the chat page
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChatPage(
                                  chatID: chatID,
                                  empName: otherUserName,
                                  empCode: empCode,
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
            ),
          ),
        ],
      ),
    );
  }
}
