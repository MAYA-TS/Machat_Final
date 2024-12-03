// // ignore_for_file: prefer_const_constructors, use_build_context_synchronously

// import 'dart:io';
// import 'package:image_picker/image_picker.dart';
// import 'package:firebase_storage/firebase_storage.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter/material.dart';
// import 'package:machat/screens/homepage.dart';

// class ProfilePictureScreen extends StatefulWidget {
//   final String userId;

//   // Constructor to receive userId when navigating to this screen
//   ProfilePictureScreen({required this.userId});

//   @override
//   _ProfilePictureScreenState createState() => _ProfilePictureScreenState();
// }

// class _ProfilePictureScreenState extends State<ProfilePictureScreen> {
//   XFile? _image; // To store the picked image
//   final ImagePicker _picker = ImagePicker(); // Image picker instance

//   // Function to pick an image from the gallery
//   Future<void> _pickImage() async {
//     final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
//     setState(() {
//       _image = pickedFile; // Store the picked image
//     });
//   }

//   Future<void> _uploadProfilePicture() async {
//     if (_image != null) {
//       try {
//         // Upload profile picture to Firebase Storage
//         final storageRef = FirebaseStorage.instance
//             .ref()
//             .child('profile_pictures/${widget.userId}.jpg');
//         UploadTask uploadTask = storageRef.putFile(File(_image!.path));
//         TaskSnapshot snapshot = await uploadTask;
//         String downloadUrl = await snapshot.ref.getDownloadURL();

//         // Get reference to the user's document in Firestore
//         DocumentReference userDocRef = FirebaseFirestore.instance
//             .collection('profilephoto')
//             .doc(widget.userId);

//         // Check if the document exists
//         DocumentSnapshot userDoc = await userDocRef.get();

//         if (userDoc.exists) {
//           // Document exists, update it
//           await userDocRef.update({
//             'profilePictureUrl': downloadUrl,
//           });
//         } else {
//           // Document doesn't exist, create it
//           await userDocRef.set(
//               {
//                 'profilePictureUrl': downloadUrl,
//                 // Add other default user data if needed
//               },
//               SetOptions(
//                   merge:
//                       true)); // merge: true ensures that the new field is added, without overwriting the entire document
//         }

//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text("Profile picture uploaded successfully!")),
//         );

//         // Navigate to home screen or perform other actions
//         Navigator.pushReplacementNamed(context, '/home');
//       } catch (e) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text("Failed to upload profile picture: $e")),
//         );
//       }
//     } else {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//             content: Text("Please select a profile picture before uploading")),
//       );
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text("Upload Profile Picture"),
//       ),
//       body: Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             // Display selected image or default icon if no image selected
//             _image == null
//                 ? Icon(Icons.person, size: 100)
//                 : Image.file(File(_image!.path), width: 100, height: 100),
//             SizedBox(height: 20),
//             // Button to pick an image from the gallery
//             ElevatedButton(
//               onPressed: _pickImage,
//               child: Text("Choose Profile Picture"),
//             ),
//             SizedBox(height: 10),
//             // Button to upload the selected image
//             ElevatedButton(
//               onPressed: _uploadProfilePicture,
//               child: Text("Upload"),
//             ),
//             SizedBox(height: 10),
//             // Button to skip uploading a profile picture
//             TextButton(
//               onPressed: () {
//                 Navigator.pushReplacement(
//                   context,
//                   MaterialPageRoute(builder: (_) => Homepage()),
//                 );
//               },
//               child: Text("Skip"),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// ignore_for_file: prefer_const_constructors, use_build_context_synchronously

// import 'dart:io';
// import 'package:image_picker/image_picker.dart';
// import 'package:firebase_storage/firebase_storage.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter/material.dart';
// import 'package:machat/screens/homepage.dart';

// class ProfilePictureScreen extends StatefulWidget {
//   final String userId;

//   ProfilePictureScreen({required this.userId});

//   @override
//   _ProfilePictureScreenState createState() => _ProfilePictureScreenState();
// }

// class _ProfilePictureScreenState extends State<ProfilePictureScreen> {
//   XFile? _image;
//   final ImagePicker _picker = ImagePicker();
//   bool isLoading = false; // Flag to track loading state

//   Future<void> _pickImage() async {
//     final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
//     setState(() {
//       _image = pickedFile;
//     });
//   }

//   Future<void> _uploadProfilePicture() async {
//     if (_image != null) {
//       setState(() {
//         isLoading = true; // Start loading
//       });

//       try {
//         final storageRef = FirebaseStorage.instance
//             .ref()
//             .child('profile_pictures/${widget.userId}.jpg');
//         UploadTask uploadTask = storageRef.putFile(File(_image!.path));
//         TaskSnapshot snapshot = await uploadTask;
//         String downloadUrl = await snapshot.ref.getDownloadURL();

//         DocumentReference userDocRef = FirebaseFirestore.instance
//             .collection('profilephoto')
//             .doc(widget.userId);

//         DocumentSnapshot userDoc = await userDocRef.get();

//         if (userDoc.exists) {
//           await userDocRef.update({
//             'profilePictureUrl': downloadUrl,
//           });
//         } else {
//           await userDocRef.set({
//             'profilePictureUrl': downloadUrl,
//           }, SetOptions(merge: true));
//         }

//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text("Profile picture uploaded successfully!")),
//         );

//         Navigator.pushReplacementNamed(context, '/home');
//       } catch (e) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text("Failed to upload profile picture: $e")),
//         );
//       } finally {
//         setState(() {
//           isLoading = false; // Stop loading
//         });
//       }
//     } else {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//             content: Text("Please select a profile picture before uploading")),
//       );
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text("Upload Profile Picture"),
//       ),
//       body: Center(
//         child: isLoading
//             ? CircularProgressIndicator() // Show loader during upload
//             : Column(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   _image == null
//                       ? Icon(Icons.person, size: 100)
//                       : Image.file(File(_image!.path), width: 100, height: 100),
//                   SizedBox(height: 20),
//                   ElevatedButton(
//                     onPressed: _pickImage,
//                     child: Text("Choose Profile Picture"),
//                   ),
//                   SizedBox(height: 10),
//                   ElevatedButton(
//                     onPressed: _uploadProfilePicture,
//                     child: Text("Upload"),
//                   ),
//                   SizedBox(height: 10),
//                   TextButton(
//                     onPressed: () {
//                       Navigator.pushReplacement(
//                         context,
//                         MaterialPageRoute(builder: (_) => Homepage()),
//                       );
//                     },
//                     child: Text("Skip"),
//                   ),
//                 ],
//               ),
//       ),
//     );
//   }
// }

import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:machat/screens/homepage.dart';

class ProfilePictureScreen extends StatefulWidget {
  final String userId;

  ProfilePictureScreen({required this.userId});

  @override
  _ProfilePictureScreenState createState() => _ProfilePictureScreenState();
}

class _ProfilePictureScreenState extends State<ProfilePictureScreen> {
  XFile? _image;
  final ImagePicker _picker = ImagePicker();
  bool isLoading = false;

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    setState(() {
      _image = pickedFile;
    });
  }

  Future<void> _uploadProfilePicture() async {
    if (_image != null) {
      setState(() {
        isLoading = true;
      });

      try {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('profile_pictures/${widget.userId}.jpg');
        UploadTask uploadTask = storageRef.putFile(File(_image!.path));
        TaskSnapshot snapshot = await uploadTask;
        String downloadUrl = await snapshot.ref.getDownloadURL();

        DocumentReference userDocRef = FirebaseFirestore.instance
            .collection('profilephoto')
            .doc(widget.userId);

        DocumentSnapshot userDoc = await userDocRef.get();

        if (userDoc.exists) {
          await userDocRef.update({
            'profilePictureUrl': downloadUrl,
          });
        } else {
          await userDocRef.set({
            'profilePictureUrl': downloadUrl,
          }, SetOptions(merge: true));
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Profile picture uploaded successfully!")),
        );

        Navigator.pushReplacementNamed(context, '/home');
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to upload profile picture: $e")),
        );
      } finally {
        setState(() {
          isLoading = false;
        });
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text("Please select a profile picture before uploading")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Upload Profile Picture"),
      ),
      body: Center(
        child: isLoading
            ? CircularProgressIndicator()
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Profile Picture Display with Highlighter
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: _image == null
                              ? Colors.grey
                              : Theme.of(context).primaryColor,
                          width: 3,
                        ),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      padding: const EdgeInsets.all(5),
                      child: ClipOval(
                        child: _image == null
                            ? Icon(Icons.person, size: 100, color: Colors.grey)
                            : Image.file(
                                File(_image!.path),
                                width: 100,
                                height: 100,
                                fit: BoxFit.cover,
                              ),
                      ),
                    ),
                    SizedBox(height: 20),

                    // Choose Picture Button
                    ElevatedButton.icon(
                      onPressed: _pickImage,
                      icon: Icon(Icons.photo_library),
                      label: Text("Choose Profile Picture"),
                      style: ElevatedButton.styleFrom(
                        padding:
                            EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                    ),
                    SizedBox(height: 20),

                    // Upload Button with Highlighted Style
                    ElevatedButton(
                      onPressed: _uploadProfilePicture,
                      style: ElevatedButton.styleFrom(
                        padding:
                            EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        backgroundColor: const Color.fromARGB(255, 2, 14, 108),
                        elevation: 10,
                        shadowColor: const Color.fromARGB(255, 2, 14, 108),
                      ),
                      child: Text(
                        "Upload",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    SizedBox(height: 20),

                    // Skip Button with Text Style
                    TextButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => Homepage()),
                        );
                      },
                      child: Text(
                        "Skip",
                        style: TextStyle(
                          fontSize: 16,
                          color: Theme.of(context).primaryColor,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
