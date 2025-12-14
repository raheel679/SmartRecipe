
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:smart_recipe_app/EditProfilePage.dart';
import 'package:smart_recipe_app/LoginPage.dart';
import 'package:smart_recipe_app/SettingsPage.dart';
import 'package:smart_recipe_app/Questions.dart';

class UserProfilePage extends StatefulWidget {
  const UserProfilePage({super.key});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  String? _profileImageUrl;
  String _name = '';
  String _email = '';
  String _dietGoal = '';
  String _age = '';
  String _weight = '';
  String _height = '';

  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  bool _isLoading = true;
  
  // User preferences data
  Map<String, dynamic>? _userPreferences;
  List<String> _availableGoals = [];
  final List<String> _allGoals = ['Weight Loss', 'Muscle Gain', 'Healthy Lifestyle'];

  // Goal-specific questions and answers
  late Map<String, Map<String, dynamic>> _goalQuestions;
  Map<String, String> _goalAnswers = {};

  @override
  void initState() {
    super.initState();
    _initializeGoalQuestions();
    _loadUserData();
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

  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        // Load basic user data
        final userDoc = await _firestore.collection('users').doc(user.uid).get();
        final userData = userDoc.data();

        if (userData != null) {
          setState(() {
            _profileImageUrl = userData['profileImageUrl'] ?? '';
            _name = userData['name'] ?? '';
            _email = userData['email'] ?? '';
            _dietGoal = userData['goal'] ?? '';
            _age = userData['age']?.toString() ?? '';
            _weight = userData['weight']?.toString() ?? '';
            _height = userData['height']?.toString() ?? '';
          });

          // Load user preferences for current goal
          await _loadUserPreferences();
         
          // Load all available goals
          await _loadAvailableGoals();

          // Load goal answers
          await _loadGoalAnswers();
        }
      } catch (e) {
        print("❌ Error loading user data: $e");
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadUserPreferences() async {
    final user = _auth.currentUser;
    if (user != null && _dietGoal.isNotEmpty) {
      try {
        final prefDoc = await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('questionnaires')
            .doc(_dietGoal)
            .get();

        if (prefDoc.exists) {
          setState(() {
            _userPreferences = prefDoc.data()!;
          });
        } else {
          setState(() {
            _userPreferences = null;
          });
        }
      } catch (e) {
        print("❌ Error loading preferences: $e");
      }
    }
  }

  Future<void> _loadAvailableGoals() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        final goalsDoc = await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('questionnaires')
            .get();

        setState(() {
          _availableGoals = goalsDoc.docs.map((doc) => doc.id).toList();
        });
      } catch (e) {
        print("❌ Error loading goals: $e");
      }
    }
  }

  Future<void> _loadGoalAnswers() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        final answersDoc = await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('goal_answers')
            .get();

        Map<String, String> loadedAnswers = {};
        for (var doc in answersDoc.docs) {
          final data = doc.data();
          if (data['answer'] != null) {
            loadedAnswers[doc.id] = data['answer'] as String;
          }
        }

        setState(() {
          _goalAnswers = loadedAnswers;
        });
      } catch (e) {
        print("❌ Error loading goal answers: $e");
      }
    }
  }

  // SIMPLIFIED goal change - just navigate to questionnaire
  void _changeGoal(String newGoal) {
    if (newGoal == _dietGoal) {
      // If same goal, navigate to questionnaire to update preferences
      _editGoalPreferences();
      return;
    }

    // Show simple confirmation dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Change to $newGoal?"),
        content: Text("Are you sure you want to change your goal from '$_dietGoal' to '$newGoal'?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _updateUserGoalAndNavigate(newGoal);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1C4322),
            ),
            child: const Text("Change Goal"),
          ),
        ],
      ),
    );
  }

  // Update user's main goal in database
  Future<void> _updateUserGoalAndNavigate(String newGoal) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // Update main goal in user document
      await _firestore.collection('users').doc(user.uid).update({
        'goal': newGoal,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update local state
      setState(() {
        _dietGoal = newGoal;
      });

      // Navigate to questionnaire for the new goal
      _navigateToGoalQuestionnaire(newGoal);
    } catch (e) {
      print("❌ Error updating goal: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error changing goal: $e")),
      );
    }
  }

  // Navigate to goal questionnaire
  void _navigateToGoalQuestionnaire(String goal) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => GoalQuestionnairePage(goal: goal),
      ),
    );
  }

  // EDIT PREFERENCES FUNCTIONALITY
  void _editGoalPreferences() async {
    final user = _auth.currentUser;
    if (user == null || _dietGoal.isEmpty) return;

    try {
      // Load current preferences
      final prefDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('questionnaires')
          .doc(_dietGoal)
          .get();

      Map<String, dynamic>? existingData;
      if (prefDoc.exists) {
        existingData = prefDoc.data()!;
      }

      // Navigate to questionnaire in edit mode
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => GoalQuestionnairePage(
            goal: _dietGoal,
            isEditing: true,
            existingData: existingData,
          ),
        ),
      ).then((_) {
        // Reload data when returning from edit
        _loadUserData();
      });
    } catch (e) {
      print("❌ Error loading preferences for edit: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error loading preferences: $e")),
      );
    }
  }

  // Quick goal setup for goals without preferences
  void _setupGoalQuickly(String goal) {
    // Directly navigate to questionnaire - questions will be answered there
    _navigateToGoalQuestionnaire(goal);
  }

  void _onMenuSelected(String choice) {
    switch (choice) {
      case 'Edit Profile':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const EditProfilePage()),
        );
        break;
      case 'Settings':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SettingsPage()),
        );
        break;
      case 'Logout':
        FirebaseAuth.instance.signOut().then((_) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const LoginPage()),
            (route) => false,
          );
        });
        break;
    }
  }

  static const List<String> _menuChoices = <String>[
    'Edit Profile',
    'Settings',
    'Logout',
  ];

  Widget _buildInfoRow(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF1C4322).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: const Color(0xFF1C4322)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value.isNotEmpty ? value : 'Not specified',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Build goal question and answer display
  Widget _buildGoalQuestionAnswer() {
    final goalQuestion = _goalQuestions[_dietGoal];
    final goalAnswer = _goalAnswers[_dietGoal];

    if (goalQuestion == null) return const SizedBox();

    return Column(
      children: [
        const Divider(),
        ListTile(
          leading: const Icon(Icons.help_outline, color: Color(0xFF1C4322)),
          title: Text(
            goalQuestion['text'],
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          subtitle: Text(
            goalAnswer ?? 'Not answered yet',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  // Build goal status indicator
  Widget _buildGoalStatus(String goal) {
    final hasPreferences = _availableGoals.contains(goal);
   
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: hasPreferences ? Colors.green.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasPreferences ? Colors.green.shade200 : Colors.orange.shade200,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasPreferences ? Icons.check_circle : Icons.info_outline,
            size: 14,
            color: hasPreferences ? Colors.green : Colors.orange,
          ),
          const SizedBox(width: 4),
          Text(
            hasPreferences ? 'Setup Complete' : 'Needs Setup',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: hasPreferences ? Colors.green : Colors.orange,
            ),
          ),
        ],
      ),
    );
  }

  // Helper method for displaying preferences in view mode
  Widget _buildPreferenceDisplayItem(String title, String value, IconData icon) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF1C4322)),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
      subtitle: Text(
        value.isEmpty ? 'Not set' : value,
        style: const TextStyle(
          fontSize: 16,
          color: Colors.black54,
        ),
      ),
      contentPadding: EdgeInsets.zero,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        title: const Text(
          "My Profile",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1C4322),
          ),
        ),
        centerTitle: true,
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: const Color(0xFF1C4322),
        actions: [
          PopupMenuButton<String>(
            onSelected: _onMenuSelected,
            itemBuilder: (BuildContext context) {
              return _menuChoices.map((String choice) {
                return PopupMenuItem<String>(
                  value: choice,
                  child: Row(
                    children: [
                      Icon(
                        choice == 'Edit Profile' ? Icons.edit :
                        choice == 'Settings' ? Icons.settings : Icons.logout,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(choice),
                    ],
                  ),
                );
              }).toList();
            },
            icon: const Icon(Icons.more_vert),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            color: Colors.white,
            elevation: 4,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1C4322)),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Hero Profile Header
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 32),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF1C4322),
                          Color.fromARGB(255, 188, 221, 189),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Profile Image with Edit Overlay
                        Stack(
                          children: [
                            Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 4,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 10,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child: _profileImageUrl != null && _profileImageUrl!.isNotEmpty
                                    ? Image.network(
                                        _profileImageUrl!,
                                        width: 120,
                                        height: 120,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) =>
                                            const Icon(Icons.person, size: 60, color: Colors.grey),
                                      )
                                    : const Icon(
                                        Icons.person,
                                        size: 60,
                                        color: Colors.white70,
                                      ),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: () {
                                  _onMenuSelected('Edit Profile');
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF4CAF50),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.edit,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _name.isNotEmpty ? _name : 'User',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _dietGoal.isNotEmpty ? _dietGoal : 'No goal set',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.white70,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Personal Details Card
                  Card(
                    elevation: 8,
                    shadowColor: const Color(0xFF1C4322).withOpacity(0.2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.info_outline, color: Color(0xFF1C4322), size: 24),
                              SizedBox(width: 8),
                              Text(
                                "Personal Details",
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1C4322),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          _buildInfoRow(Icons.email, "Email", _email),
                          const Divider(height: 1, thickness: 1, color: Colors.grey),
                          _buildInfoRow(Icons.cake, "Age", _age),
                          const Divider(height: 1, thickness: 1, color: Colors.grey),
                          _buildInfoRow(Icons.fitness_center, "Weight (kg)", _weight),
                          const Divider(height: 1, thickness: 1, color: Colors.grey),
                          _buildInfoRow(Icons.height, "Height (cm)", _height),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Goals Management Card
                  Card(
                    elevation: 8,
                    shadowColor: const Color(0xFF1C4322).withOpacity(0.2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.flag, color: Color(0xFF1C4322), size: 24),
                              SizedBox(width: 8),
                              Text(
                                "Goals Management",
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1C4322),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                         
                          // Current Goal
                          ListTile(
                            leading: const Icon(Icons.check_circle, color: Colors.green),
                            title: const Text('Current Goal', style: TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text(_dietGoal.isEmpty ? 'No goal set' : _dietGoal),
                            trailing: _dietGoal.isNotEmpty ? _buildGoalStatus(_dietGoal) : null,
                          ),
                         
                          const Divider(),
                         
                          // Change Goal Section
                          const Text(
                            'Change Your Goal',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Select a goal to update your preferences or switch to a new goal',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          const SizedBox(height: 12),
                         
                          // Goal Selection Grid
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 2.5,
                            ),
                            itemCount: _allGoals.length,
                            itemBuilder: (context, index) {
                              final goal = _allGoals[index];
                              final isCurrentGoal = goal == _dietGoal;
                              final hasPreferences = _availableGoals.contains(goal);
                             
                              return Card(
                                elevation: 2,
                                color: isCurrentGoal ? const Color(0xFF1C4322).withOpacity(0.1) : Colors.white,
                                child: ListTile(
                                  title: Text(
                                    goal,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: isCurrentGoal ? const Color(0xFF1C4322) : Colors.black87,
                                    ),
                                  ),
                                  subtitle: Text(
                                    hasPreferences ? 'Setup Complete' : 'Needs Setup',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: hasPreferences ? Colors.green : Colors.orange,
                                    ),
                                  ),
                                  trailing: Icon(
                                    isCurrentGoal ? Icons.verified : Icons.arrow_forward,
                                    color: isCurrentGoal ? Colors.green : Colors.grey,
                                    size: 16,
                                  ),
                                  onTap: () => _changeGoal(goal),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    side: BorderSide(
                                      color: isCurrentGoal ? const Color(0xFF1C4322) : Colors.grey.shade300,
                                      width: isCurrentGoal ? 2 : 1,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                         
                          // Quick Setup for Goals Without Preferences
                          if (_allGoals.any((goal) => !_availableGoals.contains(goal) && goal != _dietGoal)) ...[
                            const SizedBox(height: 16),
                            const Divider(),
                            const Text(
                              'Quick Setup Available',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 8),
                            ..._allGoals.where((goal) => !_availableGoals.contains(goal) && goal != _dietGoal).map(
                              (goal) => ListTile(
                                leading: const Icon(Icons.add_circle_outline, color: Colors.orange),
                                title: Text(goal),
                                subtitle: const Text('Click to set up preferences'),
                                trailing: const Icon(Icons.arrow_forward, size: 16),
                                onTap: () => _setupGoalQuickly(goal),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Preferences Card (Only show if user has preferences for current goal)
                  if (_userPreferences != null && _dietGoal.isNotEmpty) ...[
                    Card(
                      elevation: 8,
                      shadowColor: const Color(0xFF1C4322).withOpacity(0.2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.settings, color: Color(0xFF1C4322), size: 24),
                                const SizedBox(width: 8),
                                Text(
                                  "$_dietGoal Preferences",
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1C4322),
                                  ),
                                ),
                                const Spacer(),
                                // Edit Button
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.edit, size: 18),
                                  label: const Text('Edit'),
                                  onPressed: _editGoalPreferences,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1C4322),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                           
                            // Display goal-specific question and answer
                            _buildGoalQuestionAnswer(),
                           
                            const SizedBox(height: 16),
                           
                            // Display all preferences in a clean layout
                            _buildPreferenceDisplayItem(
                              'Plan Duration',
                              _userPreferences!['timeFrame']?.toString() ?? 'Not set',
                              Icons.calendar_today,
                            ),
                           
                            const Divider(),
                           
                            _buildPreferenceDisplayItem(
                              'Meal Frequency',
                              _userPreferences!['meals']?.toString() ?? 'Not set',
                              Icons.schedule,
                            ),
                           
                            const Divider(),
                           
                            _buildPreferenceDisplayItem(
                              'Cooking Time',
                              _userPreferences!['prepTimePreference']?.toString() ?? 'Not set',
                              Icons.timer,
                            ),
                           
                            const Divider(),
                           
                            _buildPreferenceDisplayItem(
                              'Cooking Skill',
                              _userPreferences!['cookingSkill']?.toString() ?? 'Not set',
                              Icons.man_2,
                            ),
                           
                            if (_userPreferences!['dislikes']?.toString().isNotEmpty == true) ...[
                              const Divider(),
                              _buildPreferenceDisplayItem(
                                'Foods to Avoid',
                                _userPreferences!['dislikes']?.toString() ?? '',
                                Icons.warning_amber,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // No Preferences Message for Current Goal
                  if (_userPreferences == null && _dietGoal.isNotEmpty) ...[
                    Card(
                      elevation: 8,
                      shadowColor: const Color(0xFF1C4322).withOpacity(0.2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            const Icon(Icons.settings, size: 48, color: Colors.grey),
                            const SizedBox(height: 16),
                            Text(
                              'No $_dietGoal Preferences Set',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Set up your meal plan preferences to get personalized recipes for your goal',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () => _setupGoalQuickly(_dietGoal),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1C4322),
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Set Preferences Now'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ],
              ),
            ),
    );
  }
}
