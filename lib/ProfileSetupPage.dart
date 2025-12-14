
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // For debugPrint (optional)
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'Questions.dart'; // 👈 make sure this file exists (contains GoalQuestionnairePage)
import 'height_weight_page.dart';

class ProfileSetupPage extends StatefulWidget {
  const ProfileSetupPage({super.key});

  @override
  State<ProfileSetupPage> createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends State<ProfileSetupPage> {
  String? selectedGoal;
  final List<String> goals = ["Weight Loss", "Muscle Gain", "Healthy Lifestyle"];
  bool showErrors = false;
  bool isSaving = false;
  bool isCheckingGoal = true; // Loading state for initial goal check

  @override
  void initState() {
    super.initState();
    _checkExistingGoal(); // Check if goal already exists on page load
  }

  // Check Firestore for existing goal and auto-navigate if set
  Future<void> _checkExistingGoal() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) setState(() => isCheckingGoal = false);
        return;
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists && userDoc.data() != null) {
        final existingGoal = userDoc.data()!['goal'] as String?;
        if (existingGoal != null && goals.contains(existingGoal)) {
          // Goal exists: Auto-navigate to questionnaire after brief delay
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => GoalQuestionnairePage(goal: existingGoal),
              ),
            );
          }
          return;
        }
      }
      // No valid goal: Proceed to show UI
    } catch (e) {
      // On error, default to showing UI
      if (kDebugMode) debugPrint("Error checking goal: $e");
    } finally {
      if (mounted) setState(() => isCheckingGoal = false);
    }
  }

  Future<void> _saveGoal() async {
    if (selectedGoal == null) {
      setState(() => showErrors = true);
      return;
    }

    try {
      setState(() => isSaving = true);
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("No user logged in");

      // ✅ Save selected goal to Firestore (merge to avoid overwriting other fields)
      await FirebaseFirestore.instance.collection("users").doc(user.uid).set(
        {"goal": selectedGoal},
        SetOptions(merge: true),
      );

      // ✅ Navigate to QuestionsPage
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => GoalQuestionnairePage(goal: selectedGoal!), // 👈 pass goal
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error saving goal: $e")));
    } finally {
      setState(() => isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading spinner while checking existing goal
    if (isCheckingGoal) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8F8F8),
        body: Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage("assets/Screenshot (275).png"),
              fit: BoxFit.cover,
            ),
          ),
          child: const Center(
            child: CircularProgressIndicator(
              color: Color(0xFF1C4322),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          // Background Image Container
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage("assets/Screenshot (275).png"),
                fit: BoxFit.cover,
              ),
            ),
          ),
          
          // Back Arrow Button (positioned over the background image)
         Positioned(
  top: MediaQuery.of(context).padding.top + 16, // Account for status bar
  left: 16,
  child: SafeArea(
    child: IconButton(
      icon: const Icon(
        Icons.arrow_back_ios_new,
        color: Colors.white,
        size: 28,
        shadows: [
          Shadow(
            color: Colors.black54,
            offset: Offset(0, 1),
            blurRadius: 3,
          ),
        ],
      ),
      onPressed: () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const HeightWeightPage(
              userId: "USER_ID_HERE", // pass the actual userId
            ),
          ),
        );
      },
      style: IconButton.styleFrom(
        backgroundColor: Colors.black.withOpacity(0.3), // Semi-transparent background
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.all(8),
      ),
    ),
  ),
),


          // Centered Content Container
          Center(
            child: Container(
              margin: const EdgeInsets.all(24.0),
              padding: const EdgeInsets.all(32.0),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95), // Semi-transparent white for readability
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              constraints: const BoxConstraints(maxWidth: 800), // Limit width for website-like feel
              child: Column(
                mainAxisSize: MainAxisSize.min, // Shrink to fit content
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "What's your main dietary goal?",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1C4322),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "This helps us understand what you're working towards",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 30),
                  // Goals as Small Cards
                  Flexible(
                    child: Column(
                      children: goals.map((goal) {
                        final isSelected = selectedGoal == goal;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              selectedGoal = goal;
                              showErrors = false;
                            });
                          },
                          child: Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isSelected 
                                  ? const Color(0xFF1C4322).withOpacity(0.1) 
                                  : Colors.transparent,
                              border: Border.all(
                                color: isSelected 
                                    ? const Color(0xFF1C4322) 
                                    : Colors.grey.withOpacity(0.3),
                                width: isSelected ? 2 : 1,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 5,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                                  color: isSelected 
                                      ? const Color(0xFF1C4322) 
                                      : Colors.grey.withOpacity(0.5),
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    goal,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                      color: isSelected 
                                          ? const Color(0xFF1C4322) 
                                          : Colors.black87,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1C4322),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: isSaving ? null : _saveGoal,
                      child: isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              "Continue",
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                    ),
                  ),
                  if (showErrors && selectedGoal == null)
                    const Padding(
                      padding: EdgeInsets.only(top: 10),
                      child: Center(
                        child: Text(
                          "Please select a goal to continue.",
                          style: TextStyle(color: Colors.red, fontSize: 14),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
