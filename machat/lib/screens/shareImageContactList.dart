import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ContactListScreen extends StatelessWidget {
  final String? textMessage; // Text message to be forwarded
  final String? imageUrl; // URL of the image to be forwarded
  final String currentUserId;

  const ContactListScreen({
    required this.currentUserId,
    this.textMessage,
    this.imageUrl,
  });

  // Function to confirm the action and send the message
  Future<void> _confirmAndSendMessage(
      BuildContext context, String recipientId, String type) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirm'),
          content: Text('Do you want to send this message to the $type?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false), // Cancel
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true), // Confirm
              child: Text('Send'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      final messageData = {
        'senderId': currentUserId, // Current user ID
        'timestamp': FieldValue.serverTimestamp(),
      };

      // Add the message type
      if (textMessage != null && textMessage!.isNotEmpty) {
        messageData['text'] = textMessage!;
      }

      if (imageUrl != null && imageUrl!.isNotEmpty) {
        messageData['imageUrl'] = imageUrl!;
      }

      // Send the message to a specific contact or group
      if (type == 'contact') {
        await FirebaseFirestore.instance
            .collection('chats')
            .doc(recipientId)
            .collection('messages')
            .add(messageData);
      } else if (type == 'group') {
        await FirebaseFirestore.instance
            .collection('group')
            .doc(recipientId)
            .collection('messages')
            .add(messageData);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Message sent successfully!')),
      );

      Navigator.pop(context); // Close ContactListScreen after sending
    }
  }

  // Fetch groups where the current user is a participant
  Future<List<DocumentSnapshot>> _getGroupsForCurrentUser() async {
    final currentUserId = FirebaseAuth.instance.currentUser!.uid;

    // Fetch all groups
    QuerySnapshot<Map<String, dynamic>> groupSnapshot =
        await FirebaseFirestore.instance.collection('group').get();

    // Filter the groups where the current user is a participant
    List<DocumentSnapshot> groups = groupSnapshot.docs;
    List<DocumentSnapshot> userGroups = groups.where((group) {
      List<dynamic> users = group['users'] ?? [];
      return users.contains(
          currentUserId); // Check if currentUserId is in the 'users' list
    }).toList();

    return userGroups;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Forward Message'),
      ),
      body: FutureBuilder(
        future: Future.wait([
          FirebaseFirestore.instance
              .collection('Users')
              .get(), // Fetch contacts
          _getGroupsForCurrentUser(), // Fetch groups the current user is part of
        ]),
        builder: (context, AsyncSnapshot<List<dynamic>> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('No contacts or groups available.'));
          }

          // Extract contacts and groups from the FutureBuilder data
          final contacts = snapshot.data![0].docs; // Users collection
          final groups =
              snapshot.data![1]; // Groups the current user is part of

          return ListView(
            children: [
              // Display Contacts
              // ...contacts.map((contact) {
              // return ListTile(
              //   title: Text(contact['empname'] ?? ''),
              //   subtitle: Text(contact['mobile'] ?? ''),
              //   onTap: () {
              //     _confirmAndSendMessage(
              //       context,
              //       contact.id, // Send to contact ID
              //       'contact',
              //     );
              //   },
              // );
              // }
              // ).toList(),

              // Divider(),

              // Display Groups
              ListTile(
                title: Text(
                  'Groups',
                ),
                subtitle: Text('Groups you are a participant in'),
              ),
              ...groups.map((group) {
                return ListTile(
                  title: Text(group['name'] ?? 'Unnamed Group'),
                  subtitle: Text('Tap to send message to this group'),
                  onTap: () {
                    _confirmAndSendMessage(
                      context,
                      group.id, // Use group ID for sending messages
                      'group',
                    );
                  },
                );
              }).toList(),
            ],
          );
        },
      ),
    );
  }
}
