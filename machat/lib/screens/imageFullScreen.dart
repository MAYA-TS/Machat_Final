import 'package:flutter/material.dart';

class FullScreenImageView extends StatelessWidget {
  final String imageUrl;

  // Use a named parameter in the constructor
  const FullScreenImageView({Key? key, required this.imageUrl})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: Image.network(imageUrl), // Just showing the image here
      ),
    );
  }
}
