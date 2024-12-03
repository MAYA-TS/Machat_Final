import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:machat/screens/allUserList.dart';
import 'package:machat/screens/auth/login_screen.dart';
import 'package:machat/screens/home_screen_group.dart';
import 'package:machat/screens/profileupdate.dart';
import 'package:machat/screens/singleChat.dart';

class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {
  List<Map<String, dynamic>> chats = [];
  List<Map<String, dynamic>> filteredChats = [];
  TextEditingController searchController = TextEditingController();
  bool isSearching = false;

  @override
  void initState() {
    super.initState();
    _fetchChats();
  }

  void _fetchChats() {
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      FirebaseFirestore.instance
          .collection('chats')
          .where('participants', arrayContains: currentUser.uid)
          .snapshots()
          .listen((snapshot) async {
        List<Map<String, dynamic>> tempChats = [];

        for (var doc in snapshot.docs) {
          List<String> participants = List<String>.from(doc['participants']);
          participants.remove(currentUser.uid);

          if (participants.isNotEmpty) {
            DocumentSnapshot userDoc = await FirebaseFirestore.instance
                .collection('Users')
                .doc(participants.first)
                .get();
            DocumentSnapshot userpic = await FirebaseFirestore.instance
                .collection('profilephoto')
                .doc(participants.first) // Access the profile photo by user ID
                .get();

            if (userDoc.exists) {
              Map<String, dynamic> userData =
                  userDoc.data() as Map<String, dynamic>;
              String participantName = userData['empname'] ?? 'Unknown User';
              String profilePicture =
                  userpic.exists && userpic['profilePictureUrl'] != null
                      ? userpic[
                          'profilePictureUrl'] // Fetch the profile picture URL
                      : ''; // Optional profile picture

              Timestamp lastMessageTime =
                  doc['lastMessageAt'] ?? Timestamp.now();
              String lastMessage = doc['lastMessage'] ?? 'No messages yet';

              // Fetch unread messages count
              QuerySnapshot messageSnapshot = await doc.reference
                  .collection('messages')
                  .where('isRead', isEqualTo: false)
                  .where('receiver', isEqualTo: currentUser.uid)
                  .get();
              bool hasUnreadMessages = await _checkUnreadMessages(doc.id);

              // bool hasUnreadMessages = messageSnapshot.docs.isNotEmpty;
              int unreadMessageCount = messageSnapshot.docs.length;

              // Get last message details
              QuerySnapshot lastMessageSnapshot = await doc.reference
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .limit(1)
                  .get();

              tempChats.add({
                'chatID': doc.id,
                'participantID': participants.first,
                'participantName': participantName,
                'profilePicture': profilePicture,
                'lastMessageTime': lastMessageTime,
                'lastMessage': lastMessage,
                'hasUnreadMessages': hasUnreadMessages,
                'unreadMessageCount': unreadMessageCount,
              });
            }
          }
        }

        // sort chat by lastmessagetime
        tempChats.sort((a, b) => (b['lastMessageTime'] as Timestamp)
            .compareTo(a['lastMessageTime'] as Timestamp));

        // Update the UI with the fetched chat data
        if (mounted) {
          setState(() {
            chats = tempChats;
            filteredChats = tempChats;
          });
        }
      });
    }
  }

  Future<bool> _checkUnreadMessages(String chatID) async {
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      // Fetch messages in the chat
      QuerySnapshot messagesSnapshot = await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatID)
          .collection('messages')
          .get();

      // Check if there are any unread messages
      for (var doc in messagesSnapshot.docs) {
        if (doc['senderID'] != currentUser.uid && !doc['seen']) {
          return true; // Found an unread message
        }
      }
    }
    return false; // No unread messages found
  }

  String _formatTimestamp(Timestamp timestamp) {
    DateTime date = timestamp.toDate();
    return '${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _filterChats(String query) {
    if (query.isEmpty) {
      setState(() {
        filteredChats = chats;
      });
    } else {
      setState(() {
        filteredChats = chats
            .where((chat) => chat['participantName']
                .toLowerCase()
                .contains(query.toLowerCase()))
            .toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.amber,
        title: isSearching
            ? TextField(
                controller: searchController,
                autofocus: true,
                cursorColor: Colors.white,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: "Search...",
                  hintStyle: TextStyle(color: Colors.white70),
                  border: InputBorder.none,
                ),
                onChanged: (query) => _filterChats(query),
              )
            : const Text("Chats"),
        actions: [
          IconButton(
            icon: Icon(isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                isSearching = !isSearching;
                if (!isSearching) {
                  searchController.clear();
                  filteredChats = chats;
                }
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.group),
            onPressed: _showUserList,
          ),
          PopupMenuButton<String>(
            onSelected: (String result) async {
              if (result == 'Profile') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ProfilePage()),
                );
              } else if (result == 'Sign Out') {
                await FirebaseAuth.instance.signOut();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => LoginScreen()),
                );
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'Profile',
                child: Text('Profile'),
              ),
              const PopupMenuItem<String>(
                value: 'Sign Out',
                child: Text('Sign Out'),
              ),
            ],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.0),
            ),
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: filteredChats.length,
        itemBuilder: (context, index) {
          var chat = filteredChats[index];
          return Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                radius: 20, // Increased the radius for the profile picture
                backgroundImage: chat['profilePicture'] != ''
                    ? NetworkImage(chat['profilePicture'])
                    : null,
                child: chat['profilePicture'] == ''
                    ? Icon(Icons.person, color: Colors.white, size: 24)
                    : null,
                backgroundColor: Colors.grey[300],
              ),
              title: Text(
                chat['participantName'],
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold), // Increased text size
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _formatTimestamp(chat['lastMessageTime']),
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  if (chat['hasUnreadMessages'])
                    Icon(Icons.notifications, color: Colors.red, size: 20),
                  // Padding(
                  //   padding: const EdgeInsets.only(top: 4.0),
                  //   child: CircleAvatar(
                  //     radius: 12,
                  //     backgroundColor: Colors.green,
                  //     child: Text(
                  //       '${chat['unreadMessageCount']}',
                  //       style: TextStyle(
                  //         color: Colors.white,
                  //         fontSize: 12,
                  //         fontWeight: FontWeight.bold,
                  //       ),
                  //     ),
                  //   ),
                  // ),
                ],
              ),
              onTap: () async {
                await markMessagesAsSeen(chat['chatID']);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatPage(
                      chatID: chat['chatID'],
                      empName: chat['participantName'],
                      empCode: 'Employee Code',
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          User? currentUser = FirebaseAuth.instance.currentUser;
          if (currentUser == null) {
            return;
          }
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => Userlist()),
          );
        },
        backgroundColor: Colors.amber,
        child: Icon(Icons.chat_bubble),
      ),
    );
  }

  Future<void> markMessagesAsSeen(String chatID) async {
    User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser != null) {
      // Reference to the chat document
      DocumentReference chatDocRef =
          FirebaseFirestore.instance.collection('chat').doc(chatID);

      // Update the 'seen' field for each message
      QuerySnapshot messagesSnapshot = await chatDocRef
          .collection('messages')
          .where('senderID', isNotEqualTo: currentUser.uid)
          .where('seen', isEqualTo: false)
          .get();

      for (var doc in messagesSnapshot.docs) {
        await doc.reference.update({'seen': true});
      }
    }
  }

  void _showUserList() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GroupHomePage(),
      ),
    );
  }
}
