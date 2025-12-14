import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  String? _profileImageUrl;

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    if (user != null) {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      final data = doc.data();
      setState(() {
        _nameController.text = data?['name'] ?? '';
        _emailController.text = data?['email'] ?? '';
        _profileImageUrl = data?['profileImageUrl'];
        _isLoading = false;
      });
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _firestore.collection('users').doc(user.uid).set({
        'name': _nameController.text,
        'email': _emailController.text,
        'profileImageUrl': _profileImageUrl ?? '',
      }, SetOptions(merge: true));

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profile updated successfully!")),
      );

      Navigator.pop(context); // Go back to Profile page
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error updating profile: $e")),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Edit Profile"),
        backgroundColor: const Color.fromARGB(255, 249, 249, 249),
      ),
        backgroundColor: const Color.fromARGB(255, 249, 249, 249),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundImage: _profileImageUrl != null && _profileImageUrl!.isNotEmpty
                        ? NetworkImage(_profileImageUrl!)
                        : const AssetImage("assets/no-image.jpg") as ImageProvider,
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: "Name",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: "Email",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 24),
                ElevatedButton(
  onPressed: _isSaving ? null : _saveProfile,
  style: ElevatedButton.styleFrom(
    backgroundColor: const Color.fromARGB(255, 28, 67, 34),
    padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    ),
  ),
  child: _isSaving
      ? const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
        )
      : const Text(
          "Save Changes",
          style: TextStyle(fontSize: 16, color: Colors.white),
        ),
)
                ],
              ),
            ),
    );
  }
}
