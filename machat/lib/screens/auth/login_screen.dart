// ignore_for_file: prefer_const_constructors

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:machat/screens/homepage.dart';
// import 'package:machat/screens/home_screen_group.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:machat/screens/auth/signup.dart';
// import 'package:machat/screens/home_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

late Size mq;

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Track the loading state
  bool isLoading = false;

  bool _obscurePassword = true;
  // Controllers to handle user input
  final TextEditingController empcodeController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  // Replace with your actual API URLs
  final String statusApiUrl =
      'https://unsecurepl.manappuram.com/MflEmpStatusApi/api/MaaChat/StatusByEmpCode/';
  final String oldPasswordApiUrl =
      'https://uatonpay.manappuram.com/MflEmployStatusApi/api/MaaChat/GetMaaChat/GETPSWD/ ';

  // Check employee status via API
  Future<bool> checkEmployeeStatus(String empCode, String password) async {
    try {
      final response =
          await http.get(Uri.parse('$statusApiUrl$empCode/$password'));

      // Debugging prints
      print('Status Code: ${response.statusCode}');
      print('Response Body: ${response.body}'); // Print raw response

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        if (jsonResponse.containsKey("machat")) {
          final nestedJsonString = jsonResponse["machat"];
          final validJsonString =
              nestedJsonString.replaceAll('Result:', '"Result":');

          // Print the corrected nested JSON string for debugging
          print('Corrected Nested JSON String: $validJsonString');
          // ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          //   content: Text('Invalid Username/Punching password.'),

          final nestedJson = json.decode(validJsonString);
          return nestedJson["Result"] == 1;
        } else {
          print('Key "machat" not found in response.');
          return false;
        }
      } else {
        print('Failed to load employee status: ${response.statusCode}');

        return false;
      }
    } catch (e) {
      print('Error during API call: $e');

      return false;
    }
  }

  Future<String?> fetchOldPassword(String empCode) async {
    try {
      // Make the API request to fetch the old password
      final response = await http.get(Uri.parse(
          'https://uatonpay.manappuram.com/MflEmployStatusApi/api/MaaChat/GetMaaChat/GETPSWD/$empCode/0'));

      print('Status Code: ${response.statusCode}');
      print('Response Body: ${response.body}'); // Print raw response

      if (response.statusCode == 200) {
        // Parse the JSON response
        final jsonResponse = json.decode(response.body);
        print(jsonResponse);

        // Ensure "Result" is present in the JSON response
        if (jsonResponse.containsKey("Result")) {
          // Get the array inside "Result"
          final resultArray = jsonResponse["Result"];

          // Ensure the array is not empty and contains the "PASSWORD" field
          if (resultArray is List &&
              resultArray.isNotEmpty &&
              resultArray[0].containsKey("PASSWORD")) {
            String password = resultArray[0]["PASSWORD"];
            print(
                'Extracted Password: $password'); // Print the extracted password

            // Return the extracted password
            return password;
          } else {
            print('Invalid response format or "PASSWORD" key not found.');
          }
        } else {
          print('Key "Result" not found in the response.');
        }
      } else {
        print('Failed to fetch old password: ${response.statusCode}');
      }
    } catch (e) {
      print('Error during fetching old password: $e');
    }

    // Return null if fetching the password fails
    return null;
  }

// Method to update the password in your database via API
  Future<void> updatePasswordInDB(String empCode, String password) async {
    try {
      print(password);
      print(empCode);
      final response = await http.get(Uri.parse(
          'https://uatonpay.manappuram.com/MflEmployStatusApi/api/MaaChat/GetMaaChat/UPDATEPSWD/$empCode~$password/0'));

      print('Status Code: ${response.statusCode}');
      print('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        print('Password updated successfully in the database.');
      } else {
        print(
            'Failed to update password in the database: ${response.statusCode}');
      }
    } catch (e) {
      print('Error during password update in database: $e');
    }
  }

  // Sign in method with old password handling
  Future<void> signIn() async {
    setState(() {
      isLoading = true; // Start loading
    });

    String empCode = empcodeController.text.trim();
    String password = passwordController.text.trim();

    // Check employee status first via API
    bool isLive = await checkEmployeeStatus(empCode, password);

    if (isLive) {
      // If live, try to sign in with Firebase using the entered password
      try {
        UserCredential userCredential =
            await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: '$empCode@manappuram.com', // Use empCode as email
          password: password,
        );

        // If sign-in is successful, navigate to the HomePage
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => Homepage()),
        );
      } on FirebaseAuthException catch (e) {
        print('Firebase Sign-in Error: ${e.message}');
        print('Firebase Sign-in Error: ${e.code}');

        // Check if the error is due to an invalid password
        // if (e.code == 'wrong-password') {
        // Fetch the old password if sign-in fails with the new password
        String? oldPassword = await fetchOldPassword(empCode);
        if (oldPassword != null) {
          try {
            // Sign in with the old password
            UserCredential oldUserCredential =
                await FirebaseAuth.instance.signInWithEmailAndPassword(
              email: '$empCode@manappuram.com',
              password: oldPassword,
            );

            // Reauthenticate and update the password to the new one
            await oldUserCredential.user?.updatePassword(password);

            // Update the password in your database using the new API
            await updatePasswordInDB(empCode, password);

            // After updating, navigate to the HomePage
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => Homepage()),
            );
          } on FirebaseAuthException catch (e) {
            print('Error signing in with old password: ${e.message}');
          }
        } else {
          print('Unable to fetch old password.');
        }
      }
    }
    // } else {
    //   print('Employee is not live or status check failed.');
    // }
    setState(() {
      isLoading = false; // Stop loading
    });
  }

  @override
  Widget build(BuildContext context) {
    mq = MediaQuery.of(context).size;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Login'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(top: 150.0),
              child: Center(
                child: Container(
                  width: 200,
                  height: 100,
                  child: Image.asset(
                      'images/images.png'), // Ensure the path is correct
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: TextField(
                controller: empcodeController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Employee Code',
                  hintText: 'Enter your employee code',
                ),
              ),
            ),
            const SizedBox(height: 15),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Password',
                  hintText: 'Enter Punching password',
                ),
              ),
            ),
            const SizedBox(height: 25),
            SizedBox(
              height: 65,
              width: 360,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.blue,
                ),
                onPressed: isLoading ? null : signIn,
                child: isLoading
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: const CircularProgressIndicator(
                          strokeWidth: 4, // Thinner, more subtle indicator
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Log in ',
                        style: TextStyle(fontSize: 20),
                      ),
              ),
            ),
            const SizedBox(height: 50),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Do not have an account? '),
                TextButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => Register()),
                    );
                  },
                  child: const Text(
                    'Register',
                    style: TextStyle(fontSize: 14, color: Colors.blue),
                  ),
                )
              ],
            )
          ],
        ),
      ),
    );
  }
}
