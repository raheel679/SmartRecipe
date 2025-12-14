// import 'package:flutter/material.dart';

// class ForgotPasswordPage extends StatelessWidget {
//   const ForgotPasswordPage({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color.fromARGB(255, 255, 255, 255), // Light background
//       appBar: AppBar(
//         backgroundColor: const Color.fromARGB(255, 255, 255, 255), // Dark green
//         title: const Text('Forgot Password'),
//         //centerTitle: true,
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(24.0),
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             const Icon(
//               Icons.lock_reset,
//               size: 80,
//               color: Color.fromARGB(255, 28, 67, 34), // Soft green
//             ),
//             const SizedBox(height: 20),
//             const Text(
//               'Forgot your password?',
//               style: TextStyle(
//                 fontSize: 24,
//                 fontWeight: FontWeight.bold,
//                 color: Color.fromARGB(255, 72, 89, 53),
//               ),
//               textAlign: TextAlign.center,
//             ),
//             const SizedBox(height: 10),
//             const Text(
//               'Enter your email address below and we’ll send you a link to reset your password.',
//               style: TextStyle(
//                 fontSize: 14,
//                 color: Color(0xFF93A267),
//               ),
//               textAlign: TextAlign.center,
//             ),
//             const SizedBox(height: 30),
//             TextField(
//               keyboardType: TextInputType.emailAddress,
//               decoration: InputDecoration(
//                 labelText: 'Email Address',
//                 labelStyle: const TextStyle(color: Color(0xFF485935)),
//                 border: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(10),
//                 ),
//                 prefixIcon: const Icon(Icons.email, color: Color(0xFF93A267)),
//               ),
//             ),
//             const SizedBox(height: 25),
//             ElevatedButton(
//               onPressed: () {
//                 // Add password reset logic here
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   const SnackBar(content: Text('Reset link sent!')),
//                 );
//               },
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: const Color.fromARGB(255, 28, 67, 34),
//                 padding:
//                     const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(10),
//                 ),
//               ),
//               child: const Text(
//                 'Send Reset Link',
//                 style: TextStyle(fontSize: 16, color: Colors.white),
//               ),
//             ),
//             const SizedBox(height: 20),
//             TextButton(
//               onPressed: () {
//                 Navigator.pop(context);
//               },
//               child: const Text(
//                 'Back to Login',
//                 style: TextStyle(color: Color(0xFF93A267)),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
