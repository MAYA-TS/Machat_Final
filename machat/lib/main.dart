import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:machat/screens/homepage.dart';
// import 'package:machat/screens/home_screen_group.dart';
// import 'package:machat/screens/home_screen.dart';
import 'package:machat/screens/profile_screen.dart';
import 'screens/auth/login_screen.dart'; // Your login screen

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Only initialize Firebase once at the start of the app
  try {
    await Firebase.initializeApp(
      options: FirebaseOptions(
        apiKey: "AIzaSyCAClmWl3zhveas41n6IIeUE7NQZiGxgoE",
        appId: "1:835797285711:android:74ad3d98e23f01e046e33a",
        messagingSenderId: "835797285711",
        projectId: "", // Replace with your project ID
        storageBucket: "", // Replace with your Firebase Storage Bucket URL
        // iosClientId: "", // For iOS, replace with your iOS client ID
      ),
    );
  } catch (e) {
    print("Error initializing Firebase: $e");
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Machat',
      theme: ThemeData(
        appBarTheme: const AppBarTheme(
          iconTheme: IconThemeData(color: Colors.black),
          titleTextStyle: TextStyle(color: Colors.black, fontSize: 30),
          backgroundColor: Colors.amber,
        ),
      ),
      initialRoute: '/', // Default route
      routes: {
        '/': (context) => const LoginScreen(), // Your login screen
        '/home': (context) => Homepage(), // Your home screen
        '/profile': (context) => ProfilePictureScreen(
              userId: '',
            ), // Your profile screen with userId
      },
    );
  }
}
