// import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'RecipeDetailPage.dart';

// class FullMealPage extends StatelessWidget {
//   final String goal;
//   const FullMealPage({super.key, required this.goal});

//   Future<List<Map<String, dynamic>>> fetchRecipes() async {
//    final snapshot = await FirebaseFirestore.instance
//     .collection('recipe') // ✅ exact collection name
//     .where('goal', isEqualTo: goal)
//     .where('cookingTime', isLessThanOrEqualTo: 30)
//     .get();


//     return snapshot.docs.map((doc) => doc.data()).toList();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return FutureBuilder<List<Map<String, dynamic>>>(
//       future: fetchRecipes(),
//       builder: (context, snapshot) {
//         if (snapshot.connectionState == ConnectionState.waiting) {
//           return const Center(child: CircularProgressIndicator());
//         }
//         if (!snapshot.hasData || snapshot.data!.isEmpty) {
//           return const Center(child: Text("No meals found"));
//         }

//         final recipes = snapshot.data!;
//         return ListView.builder(
//           itemCount: recipes.length,
//           itemBuilder: (context, index) {
//             final recipe = recipes[index];
//             return Card(
//               margin: const EdgeInsets.all(10),
//               child: ListTile(
//                 title: Text(recipe['title']),
//                 subtitle: Text("Time: ${recipe['cookingTime']} mins"),
//                 onTap: () {
//                   Navigator.push(
//                     context,
//                     MaterialPageRoute(
//                       builder: (_) => RecipeDetailPage(recipe: recipe, recipeId: recipeId),
//                     ),
//                   );
//                 },
//               ),
//             );
//           },
//         );
//       },
//     );
//   }
// }
