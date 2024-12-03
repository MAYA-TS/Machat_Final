// ignore_for_file: prefer_const_constructors

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:machat/screens/home_screen_group.dart';
import 'package:machat/screens/homepage.dart';
// import 'package:machat/screens/home_screen.dart';
import '../model/usermodel.dart';

class Authcontroller extends GetxController {
// Create instance

  FirebaseAuth auth = FirebaseAuth.instance;
  FirebaseFirestore db = FirebaseFirestore.instance;

  TextEditingController empname = TextEditingController();
  TextEditingController empcode = TextEditingController();
  TextEditingController email = TextEditingController();
  TextEditingController mobile = TextEditingController();
  TextEditingController password = TextEditingController();
  TextEditingController loginemail = TextEditingController();
  TextEditingController loginpassword = TextEditingController();
  var loading = false.obs;
//step 2 functions

//create account with mail and password
  signUp() async {
    try {
      loading.value = true;
      await auth.createUserWithEmailAndPassword(
          email: email.text, password: password.text);
      await addUser();
      await verifyEmail();
      Get.to(() => Homepage());
      loading.value = false;
    } catch (e) {
      Get.snackbar("error", "$e");
      loading.value = false;
    }
  }

  //add user to firebase
  addUser() async {
    UserModel user = UserModel(
      empname: empname.text,
      email: auth.currentUser?.email,
    );
    await db
        .collection("users")
        .doc(auth.currentUser?.uid)
        .collection("profile")
        .add(user.toMap());
  }
  //sign out

  signout() async {
    await auth.signOut();
  }

  //sign in
  signin() async {
    try {
      await auth.signInWithEmailAndPassword(
          email: loginemail.text, password: loginpassword.text);
    } catch (e) {
      Get.snackbar("error", "$e");
    }
  }

  verifyEmail() async {
    await auth.currentUser?.sendEmailVerification();
    Get.snackbar("email", "send");
  }
}
