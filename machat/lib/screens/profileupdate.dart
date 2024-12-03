import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class ProfilePage extends StatefulWidget {
  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  String? _profilePictureUrl;
  XFile? _imageFile;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _getProfilePicture();
  }

  void _getProfilePicture() async {
    final currentUser = _auth.currentUser;
    if (currentUser != null) {
      final profileDoc = await _firestore
          .collection('profilephoto')
          .doc(currentUser.uid)
          .get();
      if (profileDoc.exists) {
        setState(() {
          _profilePictureUrl = profileDoc['profilePictureUrl'];
        });
      }
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _imageFile = pickedFile;
      });
    }
  }

  void _cancelImageSelection() {
    setState(() {
      _imageFile = null; // Reset selected image
    });
  }

  Future<void> _updateProfilePicture() async {
    if (_imageFile == null) {
      _showAlert("Please select an image first!");
      return;
    }

    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final storageRef =
          _storage.ref().child('profile_pictures/${currentUser.uid}.jpg');
      final uploadTask = storageRef.putFile(File(_imageFile!.path));
      await uploadTask.whenComplete(() {});

      final imageUrl = await storageRef.getDownloadURL();

      await _firestore.collection('profilephoto').doc(currentUser.uid).set({
        'profilePictureUrl': imageUrl,
      }, SetOptions(merge: true));

      setState(() {
        _profilePictureUrl = imageUrl;
        _imageFile = null; // Reset _imageFile after updating
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Profile picture updated successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update profile picture')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showAlert(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Alert"),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text("OK"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Profile")),
      body: Center(
        child: Container(
          padding: EdgeInsets.all(15), // Reduced padding
          width: MediaQuery.of(context).size.width * 0.6,
          decoration: BoxDecoration(
            color: const Color.fromARGB(
                255, 235, 232, 232), // Light grey background
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.3),
                spreadRadius: 2,
                blurRadius: 5,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: SizedBox(
            height: 350, // Reduced container height
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundColor:
                            const Color.fromARGB(255, 105, 104, 104),
                        backgroundImage: _imageFile != null
                            ? FileImage(File(_imageFile!.path))
                            : _profilePictureUrl != null
                                ? NetworkImage(_profilePictureUrl!)
                                    as ImageProvider
                                : null,
                        child: _profilePictureUrl == null && _imageFile == null
                            ? Icon(Icons.account_circle,
                                size: 50, color: Colors.white)
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: InkWell(
                          onTap: _pickImage,
                          child: CircleAvatar(
                            backgroundColor: Colors.black,
                            radius: 20,
                            child: Icon(Icons.camera_alt,
                                color: Colors.white, size: 20),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                    height: 20), // Space between profile picture and buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 200,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _updateProfilePicture,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              _imageFile != null ? Colors.yellow : Colors.black,
                          foregroundColor:
                              _imageFile != null ? Colors.black : Colors.white,
                          padding: EdgeInsets.symmetric(
                              horizontal: 20, vertical: 15),
                          textStyle: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.bold),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25.0),
                          ),
                          elevation: 2,
                        ),
                        child: _isLoading
                            ? CircularProgressIndicator(
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              )
                            : Text("Update Profile Picture"),
                      ),
                    ),
                    if (_imageFile !=
                        null) // Show Cancel button only when image is selected
                      SizedBox(width: 10), // Space between buttons
                    if (_imageFile != null)
                      ElevatedButton(
                        onPressed: _cancelImageSelection,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          shape: CircleBorder(),
                          padding: EdgeInsets.all(10),
                        ),
                        child: Icon(Icons.cancel, size: 20),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
