// // lib/model/usermodel.dart

// import 'package:cloud_firestore/cloud_firestore.dart';

// class UserModel {
//   String? id, empname, empcode, email, mobile;

//   UserModel({this.empcode, this.email, this.empname, this.id, this.mobile});

//   factory UserModel.fromMap(DocumentSnapshot map) {
//     return UserModel(
//       email: map["email"],
//       empcode: map["empcode"],
//       empname: map["empname"],
//       mobile: map["mobile"],
//       id: map.id,
//     );
//   }

//   Map<String, dynamic> toMap() {
//     return {
//       "empname": empname,
//       "empcode": empcode,
//       "email": email,
//       "mobile": mobile,
//     };
//   }
// }

import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  String? id, empname, empcode, email, mobile, profilePictureUrl;

  UserModel({
    this.empcode,
    this.email,
    this.empname,
    this.id,
    this.mobile,
    this.profilePictureUrl,
  });

  // Create a UserModel from Firestore data
  factory UserModel.fromMap(DocumentSnapshot map) {
    return UserModel(
      email: map["email"],
      empcode: map["empcode"],
      empname: map["empname"],
      mobile: map["mobile"],
      id: map.id,
      profilePictureUrl: map["profilePictureUrl"], // Add this line
    );
  }

  // Convert UserModel to a map for Firestore
  Map<String, dynamic> toMap() {
    return {
      "empname": empname,
      "empcode": empcode,
      "email": email,
      "mobile": mobile,
      "profilePictureUrl": profilePictureUrl, // Add this line
    };
  }
}
