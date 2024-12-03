import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:machat/screens/shareImageContactList.dart'; // Import your ContactListScreen
import 'package:permission_handler/permission_handler.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

class GroupChatScreen extends StatefulWidget {
  final String groupId;
  final String name;

  const GroupChatScreen({Key? key, required this.groupId, required this.name})
      : super(key: key);

  @override
  _GroupChatScreenState createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ScrollController _scrollController = ScrollController();
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final TextEditingController _controller = TextEditingController();

  late String currentUserId;
  File? _imageFile;

  // To hold reply-related data
  String? _repliedMessageText;
  String? _repliedMessageSender;
  String? _repliedMessageImageUrl;
  String? _repliedMessageId;

  // List of messages to maintain state after deletion
  List<QueryDocumentSnapshot> _messages = [];

  @override
  void initState() {
    super.initState();
    currentUserId = _auth.currentUser!.uid;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Scroll to the bottom of the chat
  void _scrollToBottom() {
    Future.delayed(Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  Future<String?> _getProfilePictureUrl(String userId) async {
    try {
      final docSnapshot =
          await _firestore.collection('profilephoto').doc(userId).get();
      if (docSnapshot.exists) {
        return docSnapshot['profilePictureUrl'];
      }
    } catch (e) {
      print('Error fetching profile picture: $e');
    }
    _scrollToBottom();
    return null;
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  void _removeImage() {
    setState(() {
      _imageFile = null;
    });
  }

  Future<String?> _uploadImage(File image) async {
    try {
      final storageRef = _storage
          .ref()
          .child('chat_images/${DateTime.now().millisecondsSinceEpoch}');
      final uploadTask = storageRef.putFile(image);
      final snapshot = await uploadTask.whenComplete(() {});
      final imageUrl = await snapshot.ref.getDownloadURL();
      return imageUrl;
    } catch (e) {
      print('Error uploading image: $e');
      return null;
    }
  }

  void _sendMessage() async {
    if (_controller.text.trim().isEmpty && _imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cannot send an empty message')),
      );
      _scrollToBottom();
      return;
    }

    final Map<String, dynamic> messageData = {
      'senderId': currentUserId,
      'timestamp': FieldValue.serverTimestamp(),
    };

    if (_controller.text.isNotEmpty) {
      messageData['text'] = _controller.text.trim();
    }

    if (_imageFile != null) {
      String? imageUrl = await _uploadImage(_imageFile!);
      if (imageUrl != null) {
        messageData['imageUrl'] = imageUrl;
      }
    }

    // Include reply message if present
    if (_repliedMessageText != null) {
      messageData['replyToMessage'] = {
        'sender': _repliedMessageSender,
        'text': _repliedMessageText,
        'imageUrl': _repliedMessageImageUrl,
      };
    }

    if (messageData.length > 2) {
      await _firestore
          .collection('group')
          .doc(widget.groupId)
          .collection('messages')
          .add(messageData);
    }

    setState(() {
      _controller.clear();

      _imageFile = null;
      _repliedMessageText = null; // Clear the reply after sending
      _repliedMessageSender = null;
      _repliedMessageImageUrl = null;
      _repliedMessageId = null;
    });

    _scrollToBottom();
    _scrollController.animateTo(
      _scrollController.position.minScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  Future<bool> requestStoragePermission() async {
    if (await Permission.storage.isGranted) {
      return true;
    }

    final status = await Permission.storage.request();
    if (status.isGranted) {
      return true;
    } else if (status.isPermanentlyDenied) {
      await openAppSettings();
    }
    return false;
  }

  Future<void> downloadImage(String imageUrl) async {
    final hasPermission = await requestStoragePermission();

    if (!hasPermission) {
      print("Permission denied!");
      return;
    }

    try {
      final directory = await getExternalStorageDirectory();
      final filePath =
          "${directory!.path}/downloaded_image_${DateTime.now().millisecondsSinceEpoch}.jpg";

      final dio = Dio();
      await dio.download(imageUrl, filePath);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Image saved to Downloads folder')),
      );
      print("Image downloaded to $filePath");
    } catch (e) {
      print("Error downloading image: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to download image.')),
      );
    }
  }

  // Set the message to be replied to
  void _replyToMessage(BuildContext context, String? textMessage,
      String? imageUrl, String messageId) {
    setState(() {
      _repliedMessageText = textMessage ?? 'Replying to an image';
      _repliedMessageSender =
          currentUserId; // Track the sender of the replied message
      _repliedMessageImageUrl = imageUrl;
      _repliedMessageId = messageId; // Track the messageId for the reply
    });
    _controller.text = ''; // Clear the input field to focus on the reply.
  }

  void _redirectToContactListScreen(String? textMessage, String? imageUrl) {
    // Ensure null values are handled properly before passing them to ContactListScreen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ContactListScreen(
          textMessage:
              textMessage ?? '', // If textMessage is null, pass an empty string
          imageUrl: imageUrl, // imageUrl can stay null if it's a text message
          currentUserId: currentUserId, // Pass the current user ID here
        ),
      ),
    );
  }

  // Function to delete a message
  void _deleteMessage(String messageId) async {
    try {
      // Check if message exists
      var messageDoc = await _firestore
          .collection('group')
          .doc(widget.groupId)
          .collection('messages')
          .doc(messageId)
          .get();

      if (messageDoc.exists) {
        // Message exists, proceed to delete
        await messageDoc.reference.delete();
        print("Message deleted successfully.");

        // Update local list of messages after deletion
        setState(() {
          _messages.removeWhere((message) => message.id == messageId);
        });
      } else {
        print("Message with ID $messageId does not exist.");
      }
    } catch (e) {
      print("Error deleting message: ${e.toString()}");
    }
  }

  void _showOptionsMenu(BuildContext context, String? textMessage,
      String? imageUrl, String messageId) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.forward),
              title: Text('Forward'),
              onTap: () {
                if (mounted) {
                  Navigator.pop(context); // Close the options menu
                  _redirectToContactListScreen(textMessage, imageUrl);
                  // Implement forward logic here
                }
              },
            ),
            if (textMessage != null || imageUrl != null)
              ListTile(
                leading: Icon(Icons.reply),
                title: Text('Reply'),
                onTap: () {
                  if (mounted) {
                    Navigator.pop(context); // Close the options menu
                    _replyToMessage(context, textMessage, imageUrl, messageId);
                  }
                },
              ),
            ListTile(
              leading: Icon(Icons.delete),
              title: Text('Delete'),
              onTap: () {
                _deleteMessage(messageId);
                Navigator.pop(context); // Close the bottom sheet
              },
            ),
          ],
        );
      },
    );
  }

  Future<String?> _getEmpName(String userId) async {
    try {
      final docSnapshot =
          await _firestore.collection('Users').doc(userId).get();
      if (docSnapshot.exists) {
        return docSnapshot['empname'];
      }
    } catch (e) {
      print('Error fetching empname: $e');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.name)),
      body: Column(
        children: [
          // Display reply preview if there's a message being replied to
          if (_repliedMessageText != null || _repliedMessageImageUrl != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Container(
                color: Colors.grey[200],
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    // If it's an image reply, show a small thumbnail
                    if (_repliedMessageImageUrl != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          _repliedMessageImageUrl!,
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                        ),
                      ),
                    // If it's a text reply, show the first part of the text
                    if (_repliedMessageText != null)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: Text(
                            _repliedMessageText!.length > 30
                                ? _repliedMessageText!.substring(0, 30) + '...'
                                : _repliedMessageText!,
                            style: TextStyle(
                              fontSize: 14,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('group')
                  .doc(widget.groupId)
                  .collection('messages')
                  .orderBy('timestamp')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(child: Text('No messages.'));
                }

                final messages = snapshot.data!.docs;

                if (_messages.length != messages.length) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_scrollController.hasClients) {
                      _scrollController
                          .jumpTo(_scrollController.position.maxScrollExtent);
                    }
                  });
                }

                return ListView.builder(
                  controller: _scrollController,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final messageData =
                        messages[index].data() as Map<String, dynamic>;
                    final String message = messageData['text'] ?? '';
                    final String? imageUrl = messageData['imageUrl'];
                    final String senderId =
                        messageData['senderId'] ?? 'Unknown Sender';
                    final String messageId =
                        messages[index].id; // Get message ID
                    final Timestamp? timestamp =
                        messageData['timestamp'] as Timestamp?;

                    final String deliveryTime = timestamp != null
                        ? DateFormat('hh:mm a')
                            .format(timestamp.toDate()) // Format time
                        : 'Sending...';

                    return FutureBuilder<String?>(
                      future: _getEmpName(senderId),
                      builder: (context, empNameSnapshot) {
                        String senderName =
                            empNameSnapshot.data ?? 'Unknown Sender';

                        return FutureBuilder<String?>(
                          future: _getProfilePictureUrl(senderId),
                          builder: (context, photoSnapshot) {
                            String? profilePictureUrl = photoSnapshot.data;

                            return ListTile(
                              leading: senderId == currentUserId
                                  ? null
                                  : CircleAvatar(
                                      backgroundImage: profilePictureUrl != null
                                          ? NetworkImage(profilePictureUrl)
                                          : null,
                                      child: profilePictureUrl == null
                                          ? Icon(Icons.person)
                                          : null,
                                    ),
                              title: Align(
                                alignment: senderId == currentUserId
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: Column(
                                  crossAxisAlignment: senderId == currentUserId
                                      ? CrossAxisAlignment.end
                                      : CrossAxisAlignment.start,
                                  children: [
                                    // Show the sender's name if it's not the current user
                                    if (senderId != currentUserId)
                                      Text(
                                        senderName,
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    // If there's a reply to a message, show it as a preview
                                    if (messageData['replyToMessage'] != null)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 8.0),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Colors.grey[200],
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          padding: const EdgeInsets.all(8.0),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                messageData['replyToMessage']
                                                        ['sender'] ??
                                                    'Unknown Sender',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              if (messageData['replyToMessage']
                                                      ['text'] !=
                                                  null)
                                                Text(
                                                  messageData['replyToMessage']
                                                      ['text'],
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontStyle: FontStyle.italic,
                                                  ),
                                                ),
                                              if (messageData['replyToMessage']
                                                      ['imageUrl'] !=
                                                  null)
                                                Image.network(
                                                  messageData['replyToMessage']
                                                      ['imageUrl'],
                                                  width: 100,
                                                  height: 100,
                                                  fit: BoxFit.cover,
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    // Display the main message content
                                    if (message.isNotEmpty)
                                      Container(
                                        decoration: BoxDecoration(
                                          color: senderId == currentUserId
                                              ? Colors.amber[200]
                                              : Colors.grey[300],
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        padding: const EdgeInsets.all(8.0),
                                        child: Text(message),
                                      ),
                                    // Display the image with preview on tap
                                    if (imageUrl != null)
                                      GestureDetector(
                                        onTap: () {
                                          showDialog(
                                            context: context,
                                            builder: (context) => Dialog(
                                              child: Container(
                                                color: Colors.black,
                                                child: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    GestureDetector(
                                                      onTap: () =>
                                                          Navigator.pop(
                                                              context),
                                                      child: Align(
                                                        alignment:
                                                            Alignment.topRight,
                                                        child: Padding(
                                                          padding:
                                                              const EdgeInsets
                                                                  .all(8.0),
                                                          child: Icon(
                                                              Icons.close,
                                                              color:
                                                                  Colors.white),
                                                        ),
                                                      ),
                                                    ),
                                                    Expanded(
                                                      child: InteractiveViewer(
                                                        child: Image.network(
                                                          imageUrl,
                                                          fit: BoxFit.contain,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                        child: Container(
                                          margin:
                                              const EdgeInsets.only(top: 8.0),
                                          child: Image.network(
                                            imageUrl,
                                            width: 200,
                                            height: 200,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                    // Display the delivery time below the message or image
                                    Text(
                                      deliveryTime, // Display delivery time below each message
                                      style: TextStyle(
                                          fontSize: 10, color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                              trailing: senderId == currentUserId
                                  ? CircleAvatar(
                                      backgroundImage: profilePictureUrl != null
                                          ? NetworkImage(profilePictureUrl)
                                          : null,
                                      child: profilePictureUrl == null
                                          ? Icon(Icons.person)
                                          : null,
                                    )
                                  : null,
                              onLongPress: () => _showOptionsMenu(
                                  context, message, imageUrl, messageId),
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

          if (_imageFile != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8.0),
                    child: Image.file(
                      _imageFile!,
                      width: 80, // Thumbnail size
                      height: 80,
                      fit: BoxFit.cover,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.cancel, color: Colors.red),
                    onPressed: _removeImage,
                  ),
                ],
              ),
            ),

          // if (_imageFile != null)
          //   Padding(
          //     padding: const EdgeInsets.all(8.0),
          //     child: Image.file(_imageFile!),
          //   ),

          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.photo),
                  onPressed: _pickImage,
                ),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send, color: Colors.amber),
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
