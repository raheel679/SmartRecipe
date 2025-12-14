import 'package:flutter/material.dart';
import 'WelcomeScreen.dart'; // default back destination

class WebScaffold extends StatelessWidget {
  final Widget child;
  final String currentPage;
  final bool showBackButton;
  final VoidCallback? onBackPressed;

  const WebScaffold({
    super.key,
    required this.child,
    required this.currentPage,
    this.showBackButton = false,
    this.onBackPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          child,
          if (showBackButton)
            Positioned(
              top: 10,
              left: 10,
              child: SafeArea(
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, size: 28, color: Color(0xFF1C4322)),
                  onPressed: onBackPressed ??
                      () {
                        // Default: go back to WelcomeScreen
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                        );
                      },
                ),
              ),
            ),
        ],
      ),
    );
  }
}
