import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ChatScreen extends StatefulWidget {
  final String userId; // User ID of the chat partner
  final bool isGroupChat;

  const ChatScreen({Key? key, required this.userId, this.isGroupChat = false})
      : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? _userEmpName; // Store the employee name of the chat partner
  bool _isLoading = true; // Track loading state for the name
  DateTime?
      lastMessageDate; // Track the date of the last message for date display

  @override
  void initState() {
    super.initState();
    _fetchUserEmpName(); // Fetch employee name when screen loads
  }

  // Function to fetch employee name from Firestore
  Future<void> _fetchUserEmpName() async {
    try {
      DocumentSnapshot userSnapshot =
          await _firestore.collection('Users').doc(widget.userId).get();

      if (userSnapshot.exists) {
        setState(() {
          _userEmpName = userSnapshot['empname']; // Store employee name
        });
      }
    } catch (e) {
      print("Error fetching user details: $e");
    } finally {
      // Stop loading once data is fetched
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _sendMessage() async {
    if (_messageController.text.isNotEmpty) {
      // Get current user's ID
      String currentUserId = _auth.currentUser!.uid;

      // Add message to Firestore
      await _firestore.collection('chats').add({
        'text': _messageController.text,
        'sender': currentUserId,
        'recipientId': widget.userId,
        'timestamp': FieldValue.serverTimestamp(), // Set server timestamp
        'users': [currentUserId, widget.userId], // Store both user IDs
      });

      // Clear the input field after sending the message
      _messageController.clear();

      // Scroll to the bottom
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isLoading
            ? CircularProgressIndicator(
                color: Colors.white,
              )
            : Text(_userEmpName ?? "Chat"), // Display employee name in AppBar
      ),
      body: Column(
        children: <Widget>[
          // Display the list of messages
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('chats')
                  .where('users', arrayContains: widget.userId)
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                // Handle different states
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(child: Text('No messages yet'));
                }

                // Display messages
                final messages = snapshot.data!.docs;

                return ListView.builder(
                  reverse: true, // New messages appear at the bottom
                  controller: _scrollController,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    var message = messages[index];

                    // Safely access timestamp
                    DateTime timestamp = (message['timestamp'] != null)
                        ? (message['timestamp'] as Timestamp).toDate()
                        : DateTime.now(); // Use current time if null

                    Map<String, dynamic> messageData =
                        message.data() as Map<String, dynamic>;
                    bool isRead = messageData.containsKey('isRead') &&
                        messageData['isRead'] == true;

                    // Determine if the message is sent by the current user
                    bool isSentByCurrentUser =
                        _auth.currentUser?.uid == message['sender'];

                    // Check if it's a new day for displaying date
                    bool isNewDay = false;
                    if (lastMessageDate == null ||
                        lastMessageDate!.day != timestamp.day ||
                        lastMessageDate!.month != timestamp.month ||
                        lastMessageDate!.year != timestamp.year) {
                      isNewDay = true;
                    }

                    // Update lastMessageDate to the current timestamp
                    lastMessageDate = timestamp;

                    return Column(
                      children: [
                        // Display date if it's a new day
                        if (isNewDay)
                          Center(
                            child: Text(
                              '${timestamp.day}/${timestamp.month}/${timestamp.year}',
                              style: TextStyle(
                                color: Colors.grey,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        // The actual message widget here
                        Align(
                          alignment: isSentByCurrentUser
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: EdgeInsets.symmetric(
                                vertical: 4.0, horizontal: 8.0),
                            padding: EdgeInsets.all(10.0),
                            decoration: BoxDecoration(
                              color: isSentByCurrentUser
                                  ? Color.fromARGB(255, 244, 245, 245)
                                  : Colors.grey[200],
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                            child: Column(
                              crossAxisAlignment: isSentByCurrentUser
                                  ? CrossAxisAlignment.end
                                  : CrossAxisAlignment.start,
                              children: [
                                Text(
                                  message['text'],
                                  style: TextStyle(
                                    color: isSentByCurrentUser
                                        ? Colors.black
                                        : Colors.black,
                                  ),
                                ),
                                SizedBox(height: 4.0),
                                Text(
                                  '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey),
                                ),
                                // Display read status (blue ticks)
                                if (isRead && isSentByCurrentUser)
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Icon(Icons.check,
                                          color: Colors.blue, size: 16),
                                      SizedBox(width: 2),
                                      Icon(Icons.check,
                                          color: Colors.blue, size: 16),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          // Text input field and send button
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: "Enter your message...",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                        borderSide: BorderSide(),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
