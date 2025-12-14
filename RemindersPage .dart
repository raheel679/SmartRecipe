import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:smart_recipe_app/AddReminderPage.dart';
import 'notifications_init.dart'; // make sure plugin & init are ready

class RemindersPage extends StatelessWidget {
  const RemindersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text("You must be logged in to view reminders")),
      );
    }

    final remindersRef =
        FirebaseFirestore.instance.collection('users').doc(user.uid).collection('reminders');

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Reminders"),
        centerTitle: true,
        automaticallyImplyLeading: false,

       backgroundColor: const Color.fromARGB(255, 249, 249, 249),
      ),
      backgroundColor: const Color.fromARGB(255, 249, 249, 249),

      body: StreamBuilder<QuerySnapshot>(
        stream: remindersRef.orderBy('time').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No reminders yet. Add one!"));
          }

          final reminders = snapshot.data!.docs;

          return ListView.builder(
            itemCount: reminders.length,
            itemBuilder: (context, index) {
              final reminder = reminders[index];
              final title = reminder['title'] ?? "Untitled";
              final Timestamp? timeStamp = reminder['time'] as Timestamp?;
              final DateTime? time = timeStamp?.toDate();

              return Card(
                
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6,),
                child: ListTile(
                  title: Text(title,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(time != null
                      ? "Time: ${time.hour}:${time.minute.toString().padLeft(2, '0')}"
                      : "Unknown"),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // EDIT BUTTON
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AddReminderPage(reminder: reminder),
                            ),
                          );
                        },
                      ),
                      // DELETE BUTTON
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () async {
                          await remindersRef.doc(reminder.id).delete();
                          await flutterLocalNotificationsPlugin
                              .cancel(reminder.id.hashCode);

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Reminder deleted")),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor:const Color.fromRGBO(165, 214, 167, 1),
        child: const Icon(Icons.add, color: Colors.black,),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddReminderPage()),
          );
        },
      ),
    );
  }
}