import 'package:flutter/material.dart';
import 'package:smart_recipe_app/UserProfilePage.dart';
import 'MealRecommendationPage .dart';
import 'RemindersPage .dart';
// import 'ProfileSetupPage.dart';
// import 'UserProfilePage.dart';
// import 'ReminderListPage.dart';

class MainNavigation extends StatefulWidget {
  final String goal;

  const MainNavigation({super.key, required this.goal});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;
  late final List<Widget> _pages;

  @override
void initState() {
  super.initState();
  _pages = [
    MealRecommendationPage(goal: widget.goal), // Home
   // IngredientSearchPage(goal: widget.goal),   // Search
    const RemindersPage(),                      // Reminders
    const UserProfilePage(),                    // Profile
  ];
}

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: const Color(0xFF1C4322),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: "Search"),
          BottomNavigationBarItem(icon: Icon(Icons.alarm), label: "Reminders"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ],
      ),
    );
  }
}
