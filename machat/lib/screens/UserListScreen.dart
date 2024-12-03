import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:machat/firestore_service.dart';

class UserListScreen extends StatefulWidget {
  @override
  _UserListScreenState createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreService _firestoreService = FirestoreService();
  final ImagePicker _picker = ImagePicker();

  List<String> _selectedUsers = [];
  TextEditingController _groupNameController = TextEditingController();

  File? _groupImage;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Select Users for Group'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('Users').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text('No users found.'));
          }

          final users = snapshot.data!.docs;
          final currentUserId = _auth.currentUser!.uid;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextField(
                  controller: _groupNameController,
                  decoration: InputDecoration(
                    labelText: 'Group Name',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: ElevatedButton.icon(
                  onPressed: _pickGroupImage,
                  icon: Icon(Icons.image),
                  label: Text("Select Group Profile Photo"),
                ),
              ),
              if (_groupImage != null)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Image.file(_groupImage!, height: 100, width: 100),
                ),
              Expanded(
                child: ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    final userId = user.id;
                    final userName = user['empname'] ?? 'Unknown User';

                    if (userId == currentUserId) {
                      return SizedBox.shrink();
                    }

                    return ListTile(
                      leading: _getProfilePicture(userId),
                      title: Text(userName),
                      trailing: Checkbox(
                        value: _selectedUsers.contains(userId),
                        onChanged: (bool? selected) {
                          setState(() {
                            if (selected == true) {
                              _selectedUsers.add(userId);
                            } else {
                              _selectedUsers.remove(userId);
                            }
                          });
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isLoading ? null : _createGroup,
        child: _isLoading
            ? CircularProgressIndicator(color: Colors.white)
            : Icon(Icons.check),
        backgroundColor: _isLoading ? Colors.grey : Colors.blue,
      ),
    );
  }

  Future<void> _pickGroupImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _groupImage = File(pickedFile.path);
      });
    }
  }

  Future<String?> _uploadGroupImageToProfilePhoto() async {
    if (_groupImage == null) return null;

    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('group_images/${DateTime.now().toIso8601String()}.jpg');
      await storageRef.putFile(_groupImage!);
      final downloadUrl = await storageRef.getDownloadURL();

      final profilePhotoDoc = await _firestore.collection('profilephoto').add({
        'imageUrl': downloadUrl,
        'uploadedAt': FieldValue.serverTimestamp(),
      });

      return profilePhotoDoc.id;
    } catch (e) {
      print("Failed to upload image to profilephoto collection: $e");
      return null;
    }
  }

  void _createGroup() async {
    final groupName = _groupNameController.text.trim();

    if (groupName.isEmpty || _selectedUsers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Please provide a group name and select users.')),
      );
      return;
    }

    final currentUserId = _auth.currentUser!.uid;
    final allUsers = _selectedUsers..add(currentUserId);

    setState(() {
      _isLoading = true;
    });

    final profilePhotoId = await _uploadGroupImageToProfilePhoto();

    try {
      await _firestore.collection('group').add({
        'name': groupName,
        'createdAt': FieldValue.serverTimestamp(),
        'users': allUsers,
        'profilePhotoId': profilePhotoId,
      });

      Navigator.pop(context);
    } catch (e) {
      print("Error creating group: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create group.')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _getProfilePicture(String userId) {
    return FutureBuilder<DocumentSnapshot>(
      future: _firestore.collection('profilephoto').doc(userId).get(),
      builder: (context, photoSnapshot) {
        if (photoSnapshot.connectionState == ConnectionState.waiting ||
            !photoSnapshot.hasData ||
            photoSnapshot.data == null) {
          return CircleAvatar(
            child: Icon(Icons.person),
            radius: 25,
          );
        }

        final photoData = photoSnapshot.data!.data() as Map<String, dynamic>?;
        final profilePictureUrl = photoData?['profilePictureUrl'];

        return CircleAvatar(
          backgroundImage: profilePictureUrl != null
              ? NetworkImage(profilePictureUrl)
              : null,
          child: profilePictureUrl == null ? Icon(Icons.person) : null,
          radius: 25,
        );
      },
    );
  }
}
