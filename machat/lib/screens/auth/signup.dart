// ignore_for_file: unnecessary_const, sort_child_properties_last, implicit_call_tearoffs, sized_box_for_whitespace, avoid_print, use_build_context_synchronously, unused_local_variable, use_key_in_widget_constructors, prefer_const_constructors

import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:form_field_validator/form_field_validator.dart';
import 'package:machat/model/usermodel.dart'; // Adjust import based on your project structure
import 'package:machat/firestore_service.dart'; // Import your Firestore service
import 'package:machat/screens/auth/login_screen.dart';
// import 'package:machat/screens/home_screen.dart'; // Import the HomeScreen
import 'package:http/http.dart' as http;
import 'package:machat/screens/profile_screen.dart';

class Register extends StatefulWidget {
  @override
  State<Register> createState() => _RegisterState();
}

class _RegisterState extends State<Register> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController empnameController;
  late TextEditingController empcodeController;
  late TextEditingController mobileController;
  late TextEditingController passwordController;
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    empnameController = TextEditingController();
    empcodeController = TextEditingController();
    mobileController = TextEditingController();
    passwordController = TextEditingController();
  }

  Future<bool> checkEmployeeLive(String empCode, String password) async {
    final response = await http.get(Uri.parse(
        'https://unsecurepl.manappuram.com/MflEmpStatusApi/api/MaaChat/StatusByEmpCode/$empCode/$password'));

    if (response.statusCode == 200) {
      try {
        final jsonResponse = json.decode(response.body);
        if (jsonResponse.containsKey("machat")) {
          final nestedJsonString = jsonResponse["machat"];
          final validJsonString =
              nestedJsonString.replaceAll('Result:', '"Result":');
          final nestedJson = json.decode(validJsonString);
          print("ok");
          return nestedJson["Result"] == 1;
        } else {
          throw Exception('Key "machat" not found in response.');
        }
      } catch (e) {
        throw Exception('Failed to parse response: $e');
      }
    } else {
      throw Exception('Failed to load employee status: ${response.statusCode}');
    }
  }

  Future<void> insertEmployeeToDB(String empCode) async {
    String url =
        'https://uatonpay.manappuram.com/MflEmployStatusApi/api/MaaChat/GetMaaChat/POSTMACHATEMP/$empCode/0';
    final response = await http.get(Uri.parse(url));

    if (response.statusCode != 200) {
      throw Exception('Failed to insert employee into database');
    }
  }

  void registerUser() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      String empCode = empcodeController.text;
      String password = passwordController.text;

      // Check if employee is live before proceeding
      bool isLive = await checkEmployeeLive(empCode, password);
      if (!isLive) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Invalid Punching password.'),
        ));
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Convert empCode to email format
      String email = '$empCode@manappuram.com'; // Adjust domain as needed

      // Firebase authentication to create a new user
      try {
        UserCredential userCredential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(email: email, password: password);

        // Create a UserModel object with the input data
        UserModel newUser = UserModel(
          empname: empnameController.text,
          empcode: empCode,
          email: email,
          mobile: mobileController.text,
        );

        // Add user data to Firestore using FirestoreService
        FirestoreService firestoreService = FirestoreService();
        String userId = userCredential.user!.uid; // Get the Firebase User ID
        await firestoreService.addUser(
            newUser, userId); // Pass the userId as the second parameter

        // Insert employee into your local DB via API
        await insertEmployeeToDB(empCode);

        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('User Registration completed'),
        ));

        // Redirect to HomeScreen on successful registration
        Navigator.pushReplacement(
          context,
          // MaterialPageRoute(builder: (context) => HomePage()),
          MaterialPageRoute(
              builder: (context) => ProfilePictureScreen(userId: userId)),
        );
      } on FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use') {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('The account already exists.'),
          ));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('An error occurred during registration.'),
          ));
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('An unexpected error occurred.'),
        ));
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Register'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const LoginScreen()),
            );
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(top: 20.0),
                child: Center(
                  child: Container(
                    width: 200,
                    height: 150,
                    child: Image.asset(
                        'images/images.png'), // Adjust path to your image
                  ),
                ),
              ),
              // Padding(
              //   padding: const EdgeInsets.all(12.0),
              //   child: TextFormField(
              //     controller: empnameController,
              //     validator: MultiValidator([
              //       RequiredValidator(errorText: 'Enter Emp Name'),
              //       MinLengthValidator(3, errorText: 'Minimum 3 characters'),
              //     ]),
              //     decoration: const InputDecoration(
              //       hintText: 'Enter Emp Name',
              //       labelText: 'Emp Name',
              //       prefixIcon: Icon(
              //         Icons.person,
              //         color: Colors.green,
              //       ),
              //       errorStyle: TextStyle(fontSize: 18.0),
              //       border: OutlineInputBorder(
              //         borderSide: BorderSide(color: Colors.red),
              //         borderRadius: BorderRadius.all(Radius.circular(9.0)),
              //       ),
              //     ),
              //   ),
              // ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextFormField(
                  controller: empcodeController,
                  validator: MultiValidator([
                    RequiredValidator(errorText: 'Enter Emp Code'),
                    PatternValidator(r'^\d+$',
                        errorText: 'Enter a valid number'),
                  ]),
                  decoration: const InputDecoration(
                    hintText: 'Enter Emp Code',
                    labelText: 'Emp Code',
                    prefixIcon: Icon(
                      Icons.code,
                      color: Colors.grey,
                    ),
                    errorStyle: TextStyle(fontSize: 18.0),
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.red),
                      borderRadius: BorderRadius.all(Radius.circular(9.0)),
                    ),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(12.0),
                child: TextFormField(
                  controller: empnameController,
                  validator: MultiValidator([
                    RequiredValidator(errorText: 'Enter Emp Name'),
                    MinLengthValidator(3, errorText: 'Minimum 3 characters'),
                  ]),
                  decoration: const InputDecoration(
                    hintText: 'Enter Emp Name',
                    labelText: 'Emp Name',
                    prefixIcon: Icon(
                      Icons.person,
                      color: Colors.green,
                    ),
                    errorStyle: TextStyle(fontSize: 18.0),
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.red),
                      borderRadius: BorderRadius.all(Radius.circular(9.0)),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextFormField(
                  controller: mobileController,
                  validator: MultiValidator([
                    RequiredValidator(errorText: 'Enter mobile number'),
                    PatternValidator(r'^\d{10}$',
                        errorText: 'Enter a valid mobile number'),
                  ]),
                  decoration: const InputDecoration(
                    hintText: 'Mobile',
                    labelText: 'Mobile',
                    prefixIcon: Icon(
                      Icons.phone,
                      color: Colors.grey,
                    ),
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.red),
                      borderRadius: BorderRadius.all(Radius.circular(9.0)),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextFormField(
                  controller: passwordController,
                  validator: RequiredValidator(errorText: 'Enter Password'),
                  decoration: InputDecoration(
                    hintText: 'Punching Password',
                    labelText: 'Punching Password',
                    prefixIcon: Icon(
                      Icons.lock,
                      color: Colors.grey,
                    ),
                    border: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(9.0)),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                  obscureText: _obscurePassword,
                ),
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(18.0),
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : registerUser,
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Register'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isLoading ? Colors.grey : Colors.green,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 30.0, vertical: 10.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    empnameController.dispose();
    empcodeController.dispose();
    mobileController.dispose();
    passwordController.dispose();
    super.dispose();
  }
}
