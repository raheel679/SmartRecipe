
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'ProfileSetupPage.dart';
import 'DashboardPage.dart';

class GoalQuestionnairePage extends StatefulWidget {
  final String goal;
  final bool isEditing;
  final Map<String, dynamic>? existingData;
  
  const GoalQuestionnairePage({
    super.key, 
    required this.goal,
    this.isEditing = false,
    this.existingData
  });

  @override
  State<GoalQuestionnairePage> createState() => _GoalQuestionnairePageState();
}

class _GoalQuestionnairePageState extends State<GoalQuestionnairePage> {
  // COMMON QUESTIONS
  String? _selectedMealFrequency;
  String? _selectedTimeFrame;
 
  // SINGLE GOAL-SPECIFIC QUESTION
  String? _selectedGoalQuestion;
 
  // OPTIONAL PREFERENCES
  String? _selectedCookingSkill;
  String? _selectedPrepTime;
  final TextEditingController _dislikesController = TextEditingController();
  bool _isLoading = true;
  bool _hasExistingData = false;

  // COMMON OPTIONS
  final List<String> _timeFrameOptions = [
    "1 week",
    "2 weeks",
    "1 month",
    "Flexible - ongoing"
  ];

  final List<String> _mealOptions = [
    "3 Meals",
    "2 Meals + Snacks",
    "3 Meals + Snacks",
  ];

  final List<String> _cookingSkillOptions = [
    "Easy Recipes",
    "Some Experience",
    "Confident Cook",
  ];

  final List<String> _prepTimeOptions = [
    "Under 15 mins",
    "15-30 mins",
    "Over 30 mins",
  ];

  // SINGLE GOAL-SPECIFIC QUESTION DATA
  late Map<String, dynamic> _goalQuestions;

  @override
  void initState() {
    super.initState();
    _initializeGoalQuestions();
    _checkExistingData();
  }

  void _initializeGoalQuestions() {
    _goalQuestions = {
      'Weight Loss': {
        'text': 'What matters most for your weight loss meals?',
        'options': [
          'Feeling full and satisfied',
          'Quick and easy to make',
          'Low calorie density'
        ]
      },
      'Muscle Gain': {
        'text': 'What\'s your priority for muscle growth?',
        'options': [
          'Maximum protein intake',
          'Post-workout recovery',
          'Convenient eating'
        ]
      },
      'Healthy Lifestyle': {
        'text': 'What matters most in your healthy meals?',
        'options': [
          'Nutritional balance',
          'Fresh ingredients',
          'Easy preparation'
        ]
      }
    };
  }

  Future<void> _checkExistingData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      // Check if user already has preferences for this goal
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('questionnaires')
          .doc(widget.goal)
          .get();

      if (doc.exists && !widget.isEditing) {
        // User already has data and this is NOT an edit session
        // Navigate directly to dashboard
        final data = doc.data()!;
        _navigateToDashboard(
          dietType: data['dietType'] ?? 'balanced',
          dislikes: data['dislikes'] ?? '',
          userPreferences: data,
        );
        return;
      } else if (doc.exists && widget.isEditing) {
        // Editing mode - load existing data
        final data = doc.data()!;
        setState(() {
          _selectedTimeFrame = data['timeFrame'];
          _selectedMealFrequency = data['meals'];
          _selectedCookingSkill = data['cookingSkill'];
          _selectedPrepTime = data['prepTimePreference'];
          _selectedGoalQuestion = data['goalQuestion'];
          _dislikesController.text = data['dislikes'] ?? '';
          _hasExistingData = true;
        });
      } else if (widget.existingData != null) {
        // Load provided existing data
        setState(() {
          _selectedTimeFrame = widget.existingData!['timeFrame'];
          _selectedMealFrequency = widget.existingData!['meals'];
          _selectedCookingSkill = widget.existingData!['cookingSkill'];
          _selectedPrepTime = widget.existingData!['prepTimePreference'];
          _selectedGoalQuestion = widget.existingData!['goalQuestion'];
          _dislikesController.text = widget.existingData!['dislikes'] ?? '';
          _hasExistingData = true;
        });
      } else {
        // New setup - set defaults
        _setDefaultsBasedOnGoal();
      }
    } catch (e) {
      debugPrint("Error checking existing data: $e");
      // If error, set defaults
      _setDefaultsBasedOnGoal();
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _setDefaultsBasedOnGoal() {
    // Default preferences
    _selectedTimeFrame = "1 week";
    _selectedMealFrequency = "3 Meals";
    _selectedPrepTime = "15-30 mins";
    _selectedCookingSkill = "Easy Recipes";
   
    // Set default goal-specific answer
    final goalData = _goalQuestions[widget.goal];
    if (goalData != null) {
      _selectedGoalQuestion = goalData['options'][0];
    }
  }

  @override
  void dispose() {
    _dislikesController.dispose();
    super.dispose();
  }

  bool _validateForm() {
    if (_selectedGoalQuestion == null) {
      _showErrorSnackBar("Please answer the goal question.");
      return false;
    }
    if (_selectedMealFrequency == null) {
      _showErrorSnackBar("Please select your preferred number of meals.");
      return false;
    }
    if (_selectedTimeFrame == null) {
      _showErrorSnackBar("Please select your preferred timeframe.");
      return false;
    }
    return true;
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _handleSubmit() async {
    if (!_validateForm()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showErrorSnackBar("Please log in to save your answers.");
      return;
    }

    setState(() => _isLoading = true);

    final rawDislikes = _dislikesController.text.trim();
    final processedDislikes = _processDislikes(rawDislikes);

    final userAnswers = {
      "goal": widget.goal,
      "timeFrame": _selectedTimeFrame,
      "meals": _selectedMealFrequency,
      "cookingSkill": _selectedCookingSkill ?? "Easy Recipes",
      "prepTimePreference": _selectedPrepTime ?? "15-30 mins",
      "dislikes": rawDislikes,
      "processedDislikes": processedDislikes,
      "answeredAt": FieldValue.serverTimestamp(),
      "updatedAt": FieldValue.serverTimestamp(),
      "planDuration": _getPlanDuration(),
      "preferredMealTypes": _getPreferredMealTypes(),
     
      // Single goal-specific answer
      "goalQuestion": _selectedGoalQuestion,
      "dietType": _getDietTypeFromGoalAnswer(),
    };

    try {
      // Save to questionnaires collection
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('questionnaires')
          .doc(widget.goal)
          .set(userAnswers, SetOptions(merge: true));

      // ALSO SAVE GOAL ANSWER SEPARATELY
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('goal_answers')
          .doc(widget.goal)
          .set({
        'answer': _selectedGoalQuestion!,
        'question': _goalQuestions[widget.goal]?['text'],
        'answeredAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Update user's main goal if not already set
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
        'goal': widget.goal,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint("Answers ${widget.isEditing ? 'updated' : 'saved'}: $userAnswers");

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.isEditing 
            ? "✅ Preferences updated successfully!" 
            : "✅ Your meal plan is being created!"
          ),
        ),
      );

      if (widget.isEditing) {
        Navigator.pop(context); // Go back to profile page
      } else {
        _navigateToDashboard(
          dietType: _getDietTypeFromGoalAnswer(),
          dislikes: rawDislikes,
          userPreferences: userAnswers,
        );
      }
    } catch (e) {
      debugPrint("Error saving answers: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error saving: $e")),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _navigateToDashboard({
    required String dietType,
    required String dislikes,
    required Map<String, dynamic> userPreferences,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    String? userName = user.displayName;
    if (userName == null || userName.isEmpty) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists && doc.data()?['name'] != null) {
          userName = doc.data()!['name'];
        }
      } catch (e) {
        debugPrint("Error fetching username: $e");
        userName = 'User';
      }
    }

    // Use pushReplacement to prevent going back to questionnaire
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => DashboardPage(
          userName: userName ?? 'User',
          profileImageUrl: user.photoURL,
          goal: widget.goal,
          dietType: dietType,
          dislikes: dislikes,
          userPreferences: userPreferences,
        ),
      ),
      (route) => false, // Remove all previous routes
    );
  }

  String _getDietTypeFromGoalAnswer() {
    switch (widget.goal) {
      case 'Weight Loss':
        if (_selectedGoalQuestion?.contains('full') == true) return 'High Fiber';
        if (_selectedGoalQuestion?.contains('quick') == true) return 'Balanced';
        return 'Low Calorie';
      case 'Muscle Gain':
        if (_selectedGoalQuestion?.contains('protein') == true) return 'High Protein';
        if (_selectedGoalQuestion?.contains('recovery') == true) return 'Balanced Carbs';
        return 'Convenient';
      case 'Healthy Lifestyle':
        if (_selectedGoalQuestion?.contains('balance') == true) return 'Balanced';
        if (_selectedGoalQuestion?.contains('fresh') == true) return 'Whole Foods';
        return 'Easy Prep';
      default:
        return 'Balanced';
    }
  }

  List<String> _processDislikes(String rawDislikes) {
    if (rawDislikes.isEmpty) return [];
    return rawDislikes.split(',').map((item) => item.trim().toLowerCase()).where((item) => item.isNotEmpty).toList();
  }

  int _getPlanDuration() {
    switch (_selectedTimeFrame) {
      case "1 week":
        return 7;
      case "2 weeks":
        return 14;
      case "1 month":
        return 30;
      case "Flexible - ongoing":
        return 7;
      default:
        return 7;
    }
  }

  List<String> _getPreferredMealTypes() {
    final meals = _selectedMealFrequency ?? '';
    if (meals.contains('2 Meals')) return ['Breakfast', 'Dinner', 'Snack'];
    if (meals.contains('3 Meals')) return ['Breakfast', 'Lunch', 'Dinner'];
    if (meals.contains('3 Meals + Snacks')) return ['Breakfast', 'Lunch', 'Dinner', 'Snack'];
    return ['Breakfast', 'Lunch', 'Dinner'];
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final goalData = _goalQuestions[widget.goal];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isEditing ? "Edit ${widget.goal} Preferences" : "Create Your ${widget.goal} Plan",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (widget.isEditing) {
              Navigator.pop(context);
            } else {
              // For new setup, go back to profile setup
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const ProfileSetupPage()),
              );
            }
          },
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/Screenshot (275).png"),
            fit: BoxFit.cover,
          ),
        ),
        child: Stack(
          children: [
            // Main Content
            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Page Title
                  if (!widget.isEditing) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        _hasExistingData ? "Update Your ${widget.goal} Plan" : "Create Your ${widget.goal} Plan",
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              color: Colors.black54,
                              offset: Offset(0, 2),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Subtitle
                    Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Text(
                        _hasExistingData 
                          ? "Update your preferences for your ${widget.goal.toLowerCase()} meal plan"
                          : "Answer a few questions to get your personalized ${widget.goal.toLowerCase()} meal plan",
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white70,
                          shadows: [
                            Shadow(
                              color: Colors.black38,
                              offset: Offset(0, 1),
                              blurRadius: 3,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  // SINGLE GOAL-SPECIFIC QUESTION
                  if (goalData != null)
                    _buildRequiredQuestionCard(
                      title: "1. ${goalData['text']}",
                      tooltip: "This helps us create the perfect ${widget.goal.toLowerCase()} meals for you",
                      options: goalData['options'],
                      selectedValue: _selectedGoalQuestion,
                      onChanged: (value) => setState(() => _selectedGoalQuestion = value),
                    ),

                  // COMMON: Time Frame
                  _buildRequiredQuestionCard(
                    title: "2. Plan Duration",
                    tooltip: "Choose how long you want your meal plan",
                    options: _timeFrameOptions,
                    selectedValue: _selectedTimeFrame,
                    onChanged: (value) => setState(() => _selectedTimeFrame = value),
                  ),

                  // COMMON: Meal Frequency
                  _buildRequiredQuestionCard(
                    title: "3. Meal Frequency",
                    tooltip: "How many meals and snacks per day?",
                    options: _mealOptions,
                    selectedValue: _selectedMealFrequency,
                    onChanged: (value) => setState(() => _selectedMealFrequency = value),
                  ),

                  // OPTIONAL: Cooking Skill
                  _buildOptionalQuestionCard(
                    title: "Cooking Experience Level",
                    tooltip: "We'll adjust recipe complexity accordingly",
                    options: _cookingSkillOptions,
                    selectedValue: _selectedCookingSkill,
                    onChanged: (value) => setState(() => _selectedCookingSkill = value),
                  ),

                  // OPTIONAL: Cooking Time
                  _buildOptionalQuestionCard(
                    title: "Preferred Cooking Time",
                    tooltip: "How much time do you have for cooking?",
                    options: _prepTimeOptions,
                    selectedValue: _selectedPrepTime,
                    onChanged: (value) => setState(() => _selectedPrepTime = value),
                  ),

                  // OPTIONAL: Dislikes
                  _buildOptionalInputCard(
                    title: "Foods to Avoid",
                    tooltip: "List any ingredients you don't like or are allergic to",
                    child: TextField(
                      controller: _dislikesController,
                      decoration: InputDecoration(
                        hintText: "e.g., mushrooms, seafood, dairy...",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Color(0xFF1C4322)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      maxLines: 2,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _handleSubmit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1C4322),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              widget.isEditing || _hasExistingData ? "Update Preferences" : "Create My Meal Plan",
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                            ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequiredQuestionCard({
    required String title,
    required String tooltip,
    required List<String> options,
    required String? selectedValue,
    required Function(String?) onChanged,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF1C4322))
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.info_outline, size: 20),
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: Text(title),
                      content: Text(tooltip),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('OK'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...options.map((option) => RadioListTile<String>(
              value: option,
              groupValue: selectedValue,
              title: Text(option),
              activeColor: const Color(0xFF1C4322),
              onChanged: onChanged,
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionalQuestionCard({
    required String title,
    required String tooltip,
    required List<String> options,
    required String? selectedValue,
    required Function(String?) onChanged,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      color: Colors.grey[50],
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.grey)
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  "(Optional)",
                  style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
                ),
                IconButton(
                  icon: const Icon(Icons.info_outline, size: 16, color: Colors.grey),
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: Text(title),
                      content: Text(tooltip),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('OK'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...options.map((option) => RadioListTile<String>(
              value: option,
              groupValue: selectedValue,
              title: Text(
                option,
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
              activeColor: Colors.grey,
              onChanged: onChanged,
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionalInputCard({
    required String title,
    required String tooltip,
    required Widget child,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      color: Colors.grey[50],
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.grey)
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  "(Optional)",
                  style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
                ),
                IconButton(
                  icon: const Icon(Icons.info_outline, size: 16, color: Colors.grey),
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: Text(title),
                      content: Text(tooltip),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('OK'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}
