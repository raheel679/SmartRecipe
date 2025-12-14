import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_recipe_app/admin_dashboard.dart';
import 'ProfileSetupPage.dart';
// import 'AdminPage.dart';
import 'height_weight_page.dart';
import 'SignupPage.dart';
import 'WelcomeScreen.dart'; // Import the welcome screen

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  bool _isLoading = false;

  late AnimationController _mainController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late AnimationController _iconController;
  late Animation<double> _scaleAnimation;
  late AnimationController _buttonController;
  late Animation<double> _buttonScale;

  static const primaryColor = Color(0xFF1C4322);

  @override
  void initState() {
    super.initState();

    // Main animation
    _mainController =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnimation =
        CurvedAnimation(parent: _mainController, curve: Curves.easeInOut);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _mainController, curve: Curves.easeOutCubic),
    );
    _mainController.forward();

    // Icon animation
    _iconController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000));
    _scaleAnimation =
        CurvedAnimation(parent: _iconController, curve: Curves.elasticOut);
    _mainController.addStatusListener((status) {
      if (status == AnimationStatus.completed) _iconController.forward();
    });

    // Button scale animation
    _buttonController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 150));
    _buttonScale = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _buttonController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _mainController.dispose();
    _iconController.dispose();
    _buttonController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() => _isLoading = true);
    try {
      final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      final user = userCredential.user;
      if (user == null) return;

      // Admin account check
      if (user.email == "admin@gmail.com") {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const AdminDashboard()),
        );
        return;
      }

      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

      final data = userDoc.data();
      final hasHeightWeight =
          userDoc.exists && data?['height'] != null && data?['weight'] != null;

      if (hasHeightWeight) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const ProfileSetupPage()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => HeightWeightPage(userId: user.uid)),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Invalid email or password. Please try again.")),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 🔹 Background
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: const AssetImage("assets/12.jpg"),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.black.withOpacity(0.45),
                  BlendMode.darken,
                ),
              ),
            ),
          ),

          // 🔹 Back arrow to WelcomeScreen
          Positioned(
            top: 40,
            left: 15,
            child: SafeArea(
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white, size: 30),
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                     MaterialPageRoute(builder: (context) => const WelcomeScreen()),

                  );
                },
              ),
            ),
          ),

          // 🔹 Login form
          Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(25),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                        child: Card(
                          elevation: 14,
                          shadowColor: primaryColor.withOpacity(0.4),
                          color: Colors.white.withOpacity(0.75),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25)),
                          child: Padding(
                            padding: const EdgeInsets.all(30),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ScaleTransition(
                                    scale: _scaleAnimation,
                                    child: const Icon(Icons.eco,
                                        color: primaryColor, size: 65),
                                  ),
                                  const SizedBox(height: 15),
                                  const Text(
                                    "Welcome Back!",
                                    style: TextStyle(
                                      fontSize: 27,
                                      fontWeight: FontWeight.bold,
                                      color: primaryColor,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    "Login to continue your healthy journey 🌿",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        color: Colors.black54, fontSize: 15),
                                  ),
                                  const SizedBox(height: 40),

                                  // Email
                                  TextFormField(
                                    controller: emailController,
                                    keyboardType: TextInputType.emailAddress,
                                    textInputAction: TextInputAction.next,
                                    autofocus: true,
                                    decoration: InputDecoration(
                                      prefixIcon: const Icon(Icons.email_outlined,
                                          color: primaryColor),
                                      labelText: "Email",
                                      filled: true,
                                      fillColor: Colors.white,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return "Email is required";
                                      }
                                      if (!RegExp(r"^[^@]+@[^@]+\.[^@]+").hasMatch(value)) {
                                        return "Enter a valid email";
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 20),

                                  // Password
                                  TextFormField(
                                    controller: passwordController,
                                    obscureText: _obscurePassword,
                                    textInputAction: TextInputAction.done,
                                    decoration: InputDecoration(
                                      prefixIcon: const Icon(Icons.lock_outline,
                                          color: primaryColor),
                                      labelText: "Password",
                                      filled: true,
                                      fillColor: Colors.white,
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
                                      border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(15)),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return "Password is required";
                                      }
                                      if (value.length < 6) {
                                        return "Password must be at least 6 characters";
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 40),

                                  // Login button
                                  GestureDetector(
                                    onTapDown: (_) => _buttonController.forward(),
                                    onTapUp: (_) {
                                      _buttonController.reverse();
                                      if (_formKey.currentState!.validate()) {
                                        _login();
                                      }
                                    },
                                    child: ScaleTransition(
                                      scale: _buttonScale,
                                      child: SizedBox(
                                        width: double.infinity,
                                        height: 52,
                                        child: ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: primaryColor,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(15),
                                            ),
                                          ),
                                          onPressed: _isLoading
                                              ? null
                                              : () {
                                                  if (_formKey.currentState!.validate()) {
                                                    _login();
                                                  }
                                                },
                                          child: _isLoading
                                              ? const CircularProgressIndicator(
                                                  color: Colors.white)
                                              : const Text(
                                                  "Log In",
                                                  style: TextStyle(
                                                      fontSize: 18,
                                                      color: Colors.white),
                                                ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 25),

                                  // Sign up link
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Text("Don't have an account? "),
                                      GestureDetector(
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                                builder: (context) =>
                                                    const SignupPage()),
                                          );
                                        },
                                        child: const Text(
                                          "Sign Up",
                                          style: TextStyle(
                                              color: primaryColor,
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
