import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:smart_recipe_app/AddReminderPage.dart';
// import 'package:smart_recipe_app/height_weight_page.dart';
import 'notifications_init.dart';
import 'WelcomeScreen.dart';
import 'LoginPage.dart';
import 'SignupPage.dart';
import 'ProfileSetupPage.dart';
import 'aboutus.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: 'AIzaSyBwJO45dEgTi4ta066vS2a38zVg13E5W7Q',
      appId: '1:266429097225:android:8becb50340d4a00de5dfd8',
      messagingSenderId: '266429097225',
      projectId: 'smartrecipe-820fe',
    ),
  );
  await initLocalNotifications();

  //await initLocalNotifications(); 
  
  runApp(const Home());
}

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
  title: 'SmartRecipe',
  debugShowCheckedModeBanner: false,
  theme: ThemeData(primarySwatch: Colors.green),
  initialRoute: '/welcome',
  routes: {
    '/welcome': (context) => const WelcomeScreen(),
    '/login': (context) => const LoginPage(),
    '/signup': (context) => const SignupPage(),
    '/profilesetup': (context) => const ProfileSetupPage(),
    '/addReminder': (context) => const AddReminderPage(),
        '/about': (context) => const AboutPage(),

  },
  builder: (context, child) {
    print("Widget building: $child");
    return child!;
  },
);
  }}