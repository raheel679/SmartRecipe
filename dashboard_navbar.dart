import 'package:flutter/material.dart';

class DashboardNavbar extends StatelessWidget {
  final String userName;
  final String? profileImageUrl;
  final String selectedPage;
  final Function(String) onPageSelected;

  const DashboardNavbar({
    super.key,
    required this.userName,
    this.profileImageUrl,
    required this.selectedPage,
    required this.onPageSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color.fromARGB(255, 32, 75, 38),
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Row(
        children: [
          // Logo + Home tap
        GestureDetector(
            onTap: () => onPageSelected('Weekly Plan'),
            child: const Row(
              children: [
                SizedBox(width: 8),
                Text.rich(
                  TextSpan(
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    children: [
                      TextSpan(text: 'Smart', style: TextStyle(color: Color.fromARGB(255, 206, 145, 14))),
                      TextSpan(
                          text: 'Recipe',
                          style: TextStyle(color: Color.fromARGB(255, 86, 131, 89))),
                    ],
                  ),
                ),
              ],
            ),
          ), 


          const Spacer(),

          // Navigation items
          _navItem('Recipes'),
          const SizedBox(width: 20),
          _navItem('Weekly Plan'),
          const SizedBox(width: 20),
          _navItem('Profile'),

          const SizedBox(width: 30),

          // Avatar + username
         Row(
  children: [
    // Name first
    Text(
      userName,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    ),

    // const SizedBox(width: 10),

    // Icon / Profile circle (same visual size)
    CircleAvatar(
      radius: 22, // keep circle the same size
      backgroundImage: profileImageUrl != null
          ? NetworkImage(profileImageUrl!)
          : null,
      backgroundColor: Colors.white,
      child: profileImageUrl == null
          ? const Icon(
              Icons.person,
              color: Colors.grey,
              size: 22, // match icon size with circle
            )
          : null,
    ),
  ],
),

        ],
      ),
    );
  }

  Widget _navItem(String title) {
    final bool isActive = selectedPage == title;
    return GestureDetector(
      onTap: () => onPageSelected(title),
      child: Text(
        title,
        style: TextStyle(
          color: isActive ? const Color.fromARGB(255, 206, 145, 14) : Colors.white,
          fontSize: 16,
          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          decoration: isActive ? TextDecoration.underline : TextDecoration.none,
        ),
      ),
    );
  }
}
