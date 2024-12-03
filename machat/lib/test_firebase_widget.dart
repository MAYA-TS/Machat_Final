import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TestFirebaseWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Test Firebase Connectivity'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            FirebaseFirestore firestore = FirebaseFirestore.instance;

            try {
              // Attempt to add a test document to Firestore
              await firestore
                  .collection('test')
                  .add({'testField': 'testValue'});
              // Display a success message if the operation completes
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Document added successfully')),
              );
            } catch (e) {
              // Display an error message if the operation fails
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error adding document: $e')),
              );
            }
          },
          child: Text('Test Firebase Connection'),
        ),
      ),
    );
  }
}
