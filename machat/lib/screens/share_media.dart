import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class MediaHelper {
  static final ImagePicker _picker = ImagePicker();

  static void openMediaOptions(
      BuildContext context, Function(List<XFile>) onImagesSelected) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SizedBox(
          height: 200,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 15),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.image, color: Colors.amber),
                      iconSize: 50,
                      onPressed: () async {
                        final List<XFile>? images =
                            await _picker.pickMultiImage();
                        if (images != null && images.isNotEmpty) {
                          if (images.length > 10) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'You can select up to 10 images only.')),
                            );
                          } else {
                            onImagesSelected(
                                images); // Use callback to send images
                            Navigator.pop(context); // Close the bottom sheet
                          }
                        }
                      },
                    ),
                    const Text('Image',
                        style: TextStyle(color: Colors.amber, fontSize: 16)),
                  ],
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.insert_drive_file,
                          color: Colors.amber),
                      iconSize: 50,
                      onPressed: () {
                        // Handle document selection if needed
                      },
                    ),
                    const Text('Document',
                        style: TextStyle(color: Colors.amber, fontSize: 16)),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static void _showImagePreview(BuildContext context, List<XFile> images) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            int currentIndex = 0;

            return Dialog(
              child: Container(
                color: Colors.black,
                child: Column(
                  children: [
                    // Swipeable PageView to display images in full-screen
                    Expanded(
                      child: PageView.builder(
                        itemCount: images.length,
                        onPageChanged: (index) {
                          currentIndex = index;
                        },
                        itemBuilder: (context, index) {
                          return Stack(
                            children: [
                              // Display full-screen image
                              Center(
                                child: Image.file(
                                  File(images[index].path),
                                  fit: BoxFit.contain,
                                ),
                              ),
                              // "Remove" button on top right of each image
                              Positioned(
                                top: 40,
                                right: 20,
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      images.removeAt(index);
                                      // If no images are left, close the preview
                                      if (images.isEmpty) {
                                        Navigator.pop(context);
                                      }
                                    });
                                  },
                                  child: const CircleAvatar(
                                    radius: 20,
                                    backgroundColor: Colors.red,
                                    child: Icon(
                                      Icons.delete,
                                      size: 20,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    // Send button at the bottom
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: ElevatedButton(
                        onPressed: () {
                          // Action to send images
                          if (images.isNotEmpty) {
                            print(
                                "Images sent: ${images.map((e) => e.path).join(", ")}");
                            Navigator.pop(context); // Close the preview
                          } else {
                            Navigator.pop(context); // Close if no images left
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          padding: const EdgeInsets.symmetric(
                              vertical: 15, horizontal: 40),
                        ),
                        child: const Text("Send",
                            style:
                                TextStyle(color: Colors.white, fontSize: 18)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
