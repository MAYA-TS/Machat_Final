import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/gestures.dart';
import 'package:machat/screens/imageFullScreen.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

class ChatPage extends StatefulWidget {
  final String chatID;
  final String empName;
  final String empCode;

  const ChatPage({
    Key? key,
    required this.chatID,
    required this.empName,
    required this.empCode,
  }) : super(key: key);

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FirebaseStorage _firebaseStorage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  TapGestureRecognizer _tapRecognizer = TapGestureRecognizer();
  final ImagePicker _imagePicker = ImagePicker();

  File? _imageFile;
  String? _replyToMessageId;
  String? _replyToMessageText;

  late bool isReceiver;

  @override
  void initState() {
    super.initState();
    isReceiver = FirebaseAuth.instance.currentUser!.uid != widget.empCode;
    _tapRecognizer.onTap = () {
      // Handle tap action here (e.g., open URL)
      print('Text clicked');
    };

    if (isReceiver) {
      markMessagesAsSeen(widget.chatID, FirebaseAuth.instance.currentUser!.uid);
    }

    if (!isReceiver) {
      listenForSeenStatus(widget.chatID);
    }
  }

  void listenForSeenStatus(String chatId) {
    FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .snapshots()
        .listen((snapshot) {
      setState(() {});
    });
  }

  Future<void> markMessagesAsSeen(String chatId, String userId) async {
    final messages = await FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .where('seenBy', isNotEqualTo: userId)
        .get();

    WriteBatch batch = FirebaseFirestore.instance.batch();
    bool hasUnread = false;

    for (var message in messages.docs) {
      List seenBy = message['seenBy'] ?? [];

      if (message['senderID'] != userId && !seenBy.contains(userId)) {
        batch.update(message.reference, {
          'seenBy': FieldValue.arrayUnion([userId])
        });
        hasUnread = true;
      }
    }

    await batch.commit();

    await FirebaseFirestore.instance.collection('chats').doc(chatId).update({
      'hasUnreadMessages': !hasUnread,
    });
  }

  // Replying to a message
  void _replyToMessage(String messageId, String messageText) {
    setState(() {
      _replyToMessageId = messageId;
      _replyToMessageText = messageText;
    });
  }

  // // Forwarding a message
  // void _forwardMessage(String messageId, String messageText) {
  //   print("Forwarding message: $messageText");
  // }

  // Deleting a message
  Future<void> _deleteMessage(String messageId) async {
    await _firestore
        .collection('chats')
        .doc(widget.chatID)
        .collection('messages')
        .doc(messageId)
        .delete();
  }

  // Picking an image
  Future<void> _pickImage() async {
    final pickedFile =
        await _imagePicker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path); // Save the picked image for preview
      });
    }
  }

  // Remove the image from preview
  void _removeImage() {
    setState(() {
      _imageFile = null; // Reset the image file to null to remove the preview
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

  void _sendMessage({String? mediaUrl, String? mediaType}) async {
    if (_messageController.text.trim().isEmpty &&
        mediaUrl == null &&
        _imageFile == null) {
      return;
    }

    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      Map<String, dynamic> messageData = {
        'text': _messageController.text.trim(),
        'senderID': currentUser.uid,
        'createdAt': Timestamp.now(),
        'seen': false,
        'seenBy': [],
        'replyToMessage': _replyToMessageId != null
            ? {'messageId': _replyToMessageId, 'text': _replyToMessageText}
            : null,
      };

      if (mediaUrl != null && mediaType != null) {
        messageData['mediaUrl'] = mediaUrl;
        messageData['mediaType'] = mediaType;
      }

      // Upload image if available
      if (_imageFile != null) {
        String? imageUrl = await _uploadImage(_imageFile!);
        if (imageUrl != null) {
          messageData['mediaUrl'] = imageUrl; // Store image URL
          messageData['mediaType'] = 'image'; // Mark as image
        }
      }

      final messageRef = await _firestore
          .collection('chats')
          .doc(widget.chatID)
          .collection('messages')
          .add(messageData);

      if (messageRef.id.isNotEmpty) {
        String lastMessageText = mediaUrl != null
            ? 'Sent a $mediaType'
            : _messageController.text.trim();

        await _firestore.collection('chats').doc(widget.chatID).update({
          'lastMessage': lastMessageText,
          'lastMessageAt': Timestamp.now(),
          'hasUnreadMessages': true,
        });

        if (mounted) {
          _messageController.clear();
          _scrollToBottom();
        }
      }

      _messageController.clear();
      setState(() {
        _replyToMessageId = null;
        _replyToMessageText = null;
        _imageFile = null; // Clear the image after sending
      });

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _scrollToBottom() {
    // Ensure the scroll controller is positioned at the bottom
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.minScrollExtent,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  String _formatTimestamp(Timestamp timestamp) {
    DateTime dateTime = timestamp.toDate();
    return DateFormat('hh:mm a').format(dateTime);
  }

  bool isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.empName),
        backgroundColor: Colors.amber,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(widget.chatID)
                  .collection('messages')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                var messages = snapshot.data!.docs;

                return ListView.builder(
                  reverse: true,
                  controller: _scrollController,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    var message = messages[index];
                    bool isCurrentUser = message['senderID'] ==
                        FirebaseAuth.instance.currentUser?.uid;
                    var messageData = message.data() as Map<String, dynamic>;
                    DateTime messageDate =
                        (message['createdAt'] as Timestamp).toDate();
                    bool showDate = index == messages.length - 1;

                    if (index < messages.length - 1) {
                      DateTime previousMessageDate =
                          (messages[index + 1]['createdAt'] as Timestamp)
                              .toDate();
                      showDate = !isSameDay(messageDate, previousMessageDate);
                    }

                    bool isSeen = messageData['seenBy'] != null &&
                        messageData['seenBy'].isNotEmpty;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (showDate)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Center(
                              child: Text(
                                DateFormat('dd MMMM yyyy').format(messageDate),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ),
                          ),
                        ListTile(
                          title: Align(
                            alignment: isCurrentUser
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: IntrinsicWidth(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 8, horizontal: 12),
                                decoration: BoxDecoration(
                                  color: isCurrentUser
                                      ? Colors.amber[200]
                                      : Colors.grey[300],
                                  borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(12),
                                    topRight: Radius.circular(12),
                                    bottomLeft: isCurrentUser
                                        ? Radius.circular(12)
                                        : Radius.circular(0),
                                    bottomRight: isCurrentUser
                                        ? Radius.circular(0)
                                        : Radius.circular(12),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.grey.withOpacity(0.5),
                                      spreadRadius: 1,
                                      blurRadius: 3,
                                      offset: Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (messageData['replyToMessage'] != null)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 4),
                                        child: Text(
                                          "Replying to: ${messageData['replyToMessage']['text']}",
                                          style: TextStyle(
                                            fontStyle: FontStyle.italic,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ),
                                    _getMessageText(message['text'] ?? ''),
                                    if (messageData['mediaUrl'] != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: GestureDetector(
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    FullScreenImageView(
                                                  imageUrl:
                                                      messageData['mediaUrl'],
                                                ),
                                              ),
                                            );
                                          },
                                          child: Image.network(
                                            messageData['mediaUrl'],
                                            width: MediaQuery.of(context)
                                                    .size
                                                    .width *
                                                0.5, // 50% of the screen width
                                            height: MediaQuery.of(context)
                                                    .size
                                                    .width *
                                                0.5, // Keep it square
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        if (isSeen)
                                          Icon(Icons.check_circle,
                                              size: 20, color: Colors.green),
                                        if (!isSeen)
                                          Icon(Icons.check,
                                              size: 16, color: Colors.green),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          subtitle: Align(
                            alignment: isCurrentUser
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Text(
                              _formatTimestamp(message['createdAt']),
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ),
                          // onLongPress: () {
                          //   _showMessageOptions(
                          //       context, message.id, message['text']);
                          // },
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          // Image preview before sending
          if (_imageFile != null) // Preview the selected image
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Image.file(
                    _imageFile!,
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                  ),
                  IconButton(
                    icon: Icon(Icons.remove_circle, color: Colors.red),
                    onPressed: _removeImage, // Delete the image
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.add,
                    color: Colors.amber,
                  ),
                  onPressed: _pickImage,
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
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
                  onPressed: () {
                    _sendMessage();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Message Options (Delete, Forward)
  void _showMessageOptions(
      BuildContext context, String messageId, String messageText) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Wrap(
          children: [
            ListTile(
              title: Text('Delete'),
              onTap: () async {
                Navigator.pop(context);
                await _deleteMessage(messageId);
              },
            ),
            ListTile(
              title: Text('Reply'),
              onTap: () {
                Navigator.pop(context);
                _replyToMessage(messageId, messageText);
              },
            ),
          ],
        );
      },
    );
  }

  // Function to detect URL and make it clickable
  Text _getMessageText(String messageText) {
    final RegExp urlPattern = RegExp(
      r'((https?:\/\/)|(www\.))\S+',
      caseSensitive: false,
      multiLine: false,
    );

    // If the message contains a URL
    if (urlPattern.hasMatch(messageText)) {
      final url = messageText;

      return Text.rich(
        TextSpan(
          text: messageText,
          style: TextStyle(color: Colors.blue), // Customize link color
          recognizer: TapGestureRecognizer()
            ..onTap = () {
              print('Opening URL: $url');
            },
        ),
      );
    }

    // If no URL found, return message as plain text
    return Text(messageText);
  }
}
