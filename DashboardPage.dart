import 'package:flutter/material.dart';
import 'MealRecommendationPage .dart';
import 'weekly_plan_page.dart';
import 'UserProfilePage.dart';
import 'dashboard_navbar.dart';

class DashboardPage extends StatefulWidget {
  final String userName;          // User's name
  final String? profileImageUrl;  // Optional profile image
  final String goal;              // User's goal
  final String dietType;          // User's diet type
  final String dislikes;          // User's disliked foods
  final Map<String, dynamic> userPreferences;

  const DashboardPage({
    super.key,
    required this.userName,
    this.profileImageUrl,
    required this.goal,
    required this.dietType,
    required this.dislikes,
    required this.userPreferences,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  String selectedPage = 'Weekly Plan'; // Default selected page

  @override
  Widget build(BuildContext context) {
    // Determine which page to display
    Widget content;
    switch (selectedPage) {
      case 'Recipes':
        content = MealRecommendationPage(goal: widget.goal);
        break;
      case 'Profile':
        content = const UserProfilePage();
        break;
      case 'Weekly Plan':
      default:
        content = WeeklyPlanPage(
          goal: widget.goal,
          dietType: widget.dietType,
          dislikes: widget.dislikes,
          userPreferences: widget.userPreferences,
        );
        break;
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Top navbar
            DashboardNavbar(
              userName: widget.userName,
              profileImageUrl: widget.profileImageUrl,
              selectedPage: selectedPage,
              onPageSelected: (page) {
                setState(() {
                  selectedPage = page;
                });
              },
            ),

            // Page content
            Expanded(child: content),
          ],
        ),
      ),
    );
  }
}
