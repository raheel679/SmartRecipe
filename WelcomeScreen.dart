import 'package:flutter/material.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  // For hover effects
  bool isLoginHovered = false;
  bool isSignupHovered = false;
  bool isAboutHovered = false;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ====== BACKGROUND IMAGE ======
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/Screenshot (269).png'),
                fit: BoxFit.cover,
              ),
            ),
          ),

          // ====== OVERLAY for readability ======
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.7),
                  Colors.white.withOpacity(0.2),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),

          // ====== MAIN CONTENT ======
          Column(
            children: [
              // ====== TOP NAV BAR ======
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                width: double.infinity,
                color: Colors.transparent,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Logo
                    Row(
                      children: [
                        ClipOval(
                          child: Image.asset(
                            'assets/logosmart.png',
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                    ),

                    // ====== NAV BUTTONS ======
                    Row(
                      children: [
                        // Login
                        MouseRegion(
                          onEnter: (_) => setState(() => isLoginHovered = true),
                          onExit: (_) => setState(() => isLoginHovered = false),
                          child: TextButton(
                            onPressed: _isLoading ? null : () {
                              setState(() => _isLoading = true);
                              Navigator.pushNamed(context, '/login').then((_) {
                                setState(() => _isLoading = false);
                              });
                            },
                            child: Text(
                              'Login',
                              style: TextStyle(
                                fontSize: 16,
                                color: isLoginHovered
                                    ? Colors.orange
                                    : const Color(0xFF2E7D32),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),

                        // Signup
                        MouseRegion(
                          onEnter: (_) => setState(() => isSignupHovered = true),
                          onExit: (_) => setState(() => isSignupHovered = false),
                          child: TextButton(
                            onPressed: _isLoading ? null : () {
                              setState(() => _isLoading = true);
                              Navigator.pushNamed(context, '/signup').then((_) {
                                setState(() => _isLoading = false);
                              });
                            },
                            child: Text(
                              'Sign Up',
                              style: TextStyle(
                                fontSize: 16,
                                color: isSignupHovered
                                    ? Colors.orange
                                    : const Color(0xFF2E7D32),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),

                        // About
                        MouseRegion(
                          onEnter: (_) => setState(() => isAboutHovered = true),
                          onExit: (_) => setState(() => isAboutHovered = false),
                          child: TextButton(
                            onPressed: _isLoading ? null : () {
                              setState(() => _isLoading = true);
                              Navigator.pushNamed(context, '/about').then((_) {
                                setState(() => _isLoading = false);
                              });
                            },
                            child: Text(
                              'About Us',
                              style: TextStyle(
                                fontSize: 16,
                                color: isAboutHovered
                                    ? Colors.orange
                                    : const Color(0xFF2E7D32),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 50),

              // ====== HERO SECTION ======
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 40),

                        // Title + description
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Expanded(flex: 1, child: SizedBox()), // spacing
                            Expanded(
                              flex: 1,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Start your personalized\nmeal plan today',
                                    style: TextStyle(
                                      fontSize: 38,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF2E7D32),
                                      shadows: [
                                        Shadow(
                                          blurRadius: 5,
                                          color: Colors.black26,
                                          offset: Offset(2, 2),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  const Text(
                                    'Discover personalized recipes, track your ingredients,\nand eat healthier every day!',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 30),
                                  Center(
                                    child: SizedBox(
                                      width: 160,
                                      child: ElevatedButton(
                                        onPressed: _isLoading ? null : () {
                                          setState(() => _isLoading = true);
                                          Navigator.pushNamed(context, '/login').then((_) {
                                            setState(() => _isLoading = false);
                                          });
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color.fromARGB(
                                              255, 190, 98, 11),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 20, vertical: 12),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(15),
                                          ),
                                          elevation: 6,
                                          shadowColor: Colors.black26,
                                        ),
                                        child: _isLoading
                                            ? const SizedBox(
                                                width: 20,
                                                height: 20,
                                                child: CircularProgressIndicator(
                                                  color: Colors.white,
                                                  strokeWidth: 2,
                                                ),
                                              )
                                            : const Text(
                                                'Get Started',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  const Text(
                                    'Eat smart, feel great, and live better — one meal at a time!',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.black87,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 70),

                        // ====== FEATURE SECTION ======
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            FeatureCard(
                              icon: Icons.restaurant_menu,
                              title: "Healthy Recipes",
                              description:
                                  "Discover nutritious meals tailored to your goals.",
                            ),
                            FeatureCard(
                              icon: Icons.schedule,
                              title: "Smart Planner",
                              description:
                                  "Automatically organize your weekly meals.",
                            ),
                            FeatureCard(
                              icon: Icons.track_changes,
                              title: "Track Progress",
                              description:
                                  "Monitor your habits and stay motivated.",
                            ),
                          ],
                        ),

                        const SizedBox(height: 60),

                        // ====== FOOTER ======
                        Container(
                          width: double.infinity,
                          color: Colors.white.withOpacity(0.8),
                          padding: const EdgeInsets.symmetric(
                              vertical: 20, horizontal: 40),
                          child: const Column(
                            children: [
                              Text(
                                "© 2025 SmartRecipe. All rights reserved.",
                                style: TextStyle(
                                    fontSize: 12, color: Colors.black54),
                              ),
                              SizedBox(height: 5),
                              Text(
                                "Follow us on Instagram @smartrecipe",
                                style: TextStyle(
                                    fontSize: 12, color: Colors.black54),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Loading overlay
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}

// ====== FEATURE CARD WIDGET ======
class FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const FeatureCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black26.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(2, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, size: 40, color: const Color(0xFF2E7D32)),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Color(0xFF2E7D32),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Colors.black87),
          ),
        ],
      ),
    );
  }
}