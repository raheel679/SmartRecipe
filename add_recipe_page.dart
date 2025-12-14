import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddRecipePage extends StatefulWidget {
  final String collection;
  final bool isEditing;
  final Map<String, dynamic>? recipeData;
  final String? recipeId;
  
  const AddRecipePage({
    super.key,
    required this.collection,
    this.isEditing = false,
    this.recipeData,
    this.recipeId,
  });

  @override
  State<AddRecipePage> createState() => _AddRecipePageState();
}

class _AddRecipePageState extends State<AddRecipePage> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Form controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _mealTypeController = TextEditingController();
  final TextEditingController _complexityController = TextEditingController();
  final TextEditingController _prepTimeController = TextEditingController();
  final TextEditingController _cookTimeController = TextEditingController();
  final TextEditingController _caloriesController = TextEditingController();
  final TextEditingController _proteinController = TextEditingController();
  final TextEditingController _carbsController = TextEditingController();
  final TextEditingController _fatsController = TextEditingController();
  final TextEditingController _fiberController = TextEditingController();
  final TextEditingController _imageUrlController = TextEditingController();
  
  List<String> _ingredients = [];
  List<String> _instructions = [];
  List<String> _tags = [];
  List<String> _goalTags = [];
  
  final TextEditingController _ingredientController = TextEditingController();
  final TextEditingController _instructionController = TextEditingController();
  final TextEditingController _tagController = TextEditingController();
  final TextEditingController _goalTagController = TextEditingController();
  
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.isEditing && widget.recipeData != null) {
      _populateFormData();
    }
  }

  void _populateFormData() {
    final data = widget.recipeData!;
    
    _nameController.text = data['name']?.toString() ?? '';
    _descriptionController.text = data['description']?.toString() ?? '';
    _mealTypeController.text = data['mealType']?.toString() ?? '';
    _complexityController.text = data['complexity']?.toString() ?? '';
    _prepTimeController.text = data['prepTime']?.toString() ?? '';
    _cookTimeController.text = data['cookTime']?.toString() ?? '';
    _caloriesController.text = data['calories']?.toString() ?? '';
    _proteinController.text = data['protein']?.toString() ?? '';
    _carbsController.text = data['carbs']?.toString() ?? '';
    _fatsController.text = data['fats']?.toString() ?? '';
    _fiberController.text = data['fiber']?.toString() ?? '';
    _imageUrlController.text = data['imageUrl']?.toString() ?? '';
    
    if (data['ingredients'] != null) {
      _ingredients = List<String>.from(data['ingredients']);
    }
    if (data['instructions'] != null) {
      _instructions = List<String>.from(data['instructions']);
    }
    if (data['tags'] != null) {
      _tags = List<String>.from(data['tags']);
    }
    if (data['goalTags'] != null) {
      _goalTags = List<String>.from(data['goalTags']);
    }
  }

  Future<void> _saveRecipe() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final recipeData = {
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'mealType': _mealTypeController.text.trim(),
        'complexity': _complexityController.text.trim(),
        'prepTime': int.tryParse(_prepTimeController.text) ?? 0,
        'cookTime': int.tryParse(_cookTimeController.text) ?? 0,
        'totalTime': (int.tryParse(_prepTimeController.text) ?? 0) + 
                    (int.tryParse(_cookTimeController.text) ?? 0),
        'calories': int.tryParse(_caloriesController.text) ?? 0,
        'protein': int.tryParse(_proteinController.text) ?? 0,
        'carbs': int.tryParse(_carbsController.text) ?? 0,
        'fats': int.tryParse(_fatsController.text) ?? 0,
        'fiber': int.tryParse(_fiberController.text) ?? 0,
        'ingredients': _ingredients,
        'instructions': _instructions,
        'tags': _tags,
        'goalTags': _goalTags,
        'imageUrl': _imageUrlController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Add created timestamp if it's a new recipe
      if (!widget.isEditing) {
        recipeData['createdAt'] = FieldValue.serverTimestamp();
      }

      if (widget.isEditing && widget.recipeId != null) {
        // Update existing recipe
        await _firestore
            .collection(widget.collection)
            .doc(widget.recipeId)
            .update(recipeData);
        print('✅ Recipe updated successfully');
      } else {
        // Add new recipe
        await _firestore.collection(widget.collection).add(recipeData);
        print('✅ Recipe added successfully');
      }

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isEditing 
              ? 'Recipe updated successfully!' 
              : 'Recipe added successfully!'
          ),
          backgroundColor: Colors.green,
        ),
      );

      // Return true to indicate success and trigger refresh
      Navigator.pop(context, true);

    } catch (e) {
      print('❌ Error saving recipe: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving recipe: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  void _addIngredient() {
    final ingredient = _ingredientController.text.trim();
    if (ingredient.isNotEmpty && !_ingredients.contains(ingredient)) {
      setState(() {
        _ingredients.add(ingredient);
        _ingredientController.clear();
      });
    }
  }

  void _removeIngredient(int index) {
    setState(() {
      _ingredients.removeAt(index);
    });
  }

  void _addInstruction() {
    final instruction = _instructionController.text.trim();
    if (instruction.isNotEmpty && !_instructions.contains(instruction)) {
      setState(() {
        _instructions.add(instruction);
        _instructionController.clear();
      });
    }
  }

  void _removeInstruction(int index) {
    setState(() {
      _instructions.removeAt(index);
    });
  }

  void _addTag() {
    final tag = _tagController.text.trim();
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() {
        _tags.add(tag);
        _tagController.clear();
      });
    }
  }

  void _removeTag(int index) {
    setState(() {
      _tags.removeAt(index);
    });
  }

  void _addGoalTag() {
    final tag = _goalTagController.text.trim();
    if (tag.isNotEmpty && !_goalTags.contains(tag)) {
      setState(() {
        _goalTags.add(tag);
        _goalTagController.clear();
      });
    }
  }

  void _removeGoalTag(int index) {
    setState(() {
      _goalTags.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isEditing ? 'Edit Recipe' : 'Add Recipe',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isSaving ? null : _saveRecipe,
            tooltip: 'Save Recipe',
          ),
        ],
      ),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Basic Information
                    const Text(
                      'Basic Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Recipe Name *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a recipe name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                    
                    TextFormField(
                      controller: _mealTypeController,
                      decoration: const InputDecoration(
                        labelText: 'Meal Type (e.g., Breakfast, Lunch)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    TextFormField(
                      controller: _complexityController,
                      decoration: const InputDecoration(
                        labelText: 'Complexity (e.g., Easy, Medium, Hard)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    TextFormField(
                      controller: _imageUrlController,
                      decoration: const InputDecoration(
                        labelText: 'Image URL (optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Cooking Times
                    const Text(
                      'Cooking Times (minutes)',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _prepTimeController,
                            decoration: const InputDecoration(
                              labelText: 'Prep Time',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _cookTimeController,
                            decoration: const InputDecoration(
                              labelText: 'Cook Time',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    // Nutrition Information
                    const Text(
                      'Nutrition Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width: 150,
                          child: TextFormField(
                            controller: _caloriesController,
                            decoration: const InputDecoration(
                              labelText: 'Calories',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        SizedBox(
                          width: 150,
                          child: TextFormField(
                            controller: _proteinController,
                            decoration: const InputDecoration(
                              labelText: 'Protein (g)',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        SizedBox(
                          width: 150,
                          child: TextFormField(
                            controller: _carbsController,
                            decoration: const InputDecoration(
                              labelText: 'Carbs (g)',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        SizedBox(
                          width: 150,
                          child: TextFormField(
                            controller: _fatsController,
                            decoration: const InputDecoration(
                              labelText: 'Fats (g)',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        SizedBox(
                          width: 150,
                          child: TextFormField(
                            controller: _fiberController,
                            decoration: const InputDecoration(
                              labelText: 'Fiber (g)',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    // Ingredients
                    const Text(
                      'Ingredients',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _ingredientController,
                            decoration: const InputDecoration(
                              labelText: 'Add ingredient',
                              border: OutlineInputBorder(),
                            ),
                            onSubmitted: (_) => _addIngredient(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: _addIngredient,
                          tooltip: 'Add Ingredient',
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    
                    if (_ingredients.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Added Ingredients:'),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: _ingredients.asMap().entries.map((entry) {
                              final index = entry.key;
                              final ingredient = entry.value;
                              return Chip(
                                label: Text(ingredient),
                                onDeleted: () => _removeIngredient(index),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    
                    // Instructions
                    const Text(
                      'Instructions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _instructionController,
                            decoration: const InputDecoration(
                              labelText: 'Add instruction step',
                              border: OutlineInputBorder(),
                            ),
                            onSubmitted: (_) => _addInstruction(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: _addInstruction,
                          tooltip: 'Add Instruction',
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    
                    if (_instructions.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Added Instructions:'),
                          const SizedBox(height: 8),
                          ..._instructions.asMap().entries.map((entry) {
                            final index = entry.key;
                            final instruction = entry.value;
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: CircleAvatar(
                                  child: Text('${index + 1}'),
                                ),
                                title: Text(instruction),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _removeInstruction(index),
                                ),
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    
                    // Tags
                    const Text(
                      'Tags',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _tagController,
                            decoration: const InputDecoration(
                              labelText: 'Add tag (e.g., Vegetarian, Low-carb)',
                              border: OutlineInputBorder(),
                            ),
                            onSubmitted: (_) => _addTag(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: _addTag,
                          tooltip: 'Add Tag',
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    
                    if (_tags.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Added Tags:'),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: _tags.asMap().entries.map((entry) {
                              final index = entry.key;
                              final tag = entry.value;
                              return Chip(
                                label: Text(tag),
                                onDeleted: () => _removeTag(index),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    
                    // Goal Tags
                    const Text(
                      'Goal Tags',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _goalTagController,
                            decoration: const InputDecoration(
                              labelText: 'Add goal tag (e.g., Weight Loss, Muscle Gain)',
                              border: OutlineInputBorder(),
                            ),
                            onSubmitted: (_) => _addGoalTag(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: _addGoalTag,
                          tooltip: 'Add Goal Tag',
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    
                    if (_goalTags.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Added Goal Tags:'),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: _goalTags.asMap().entries.map((entry) {
                              final index = entry.key;
                              final tag = entry.value;
                              return Chip(
                                label: Text(tag),
                                onDeleted: () => _removeGoalTag(index),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    
                    // Save Button
                    const SizedBox(height: 32),
                    Center(
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveRecipe,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(200, 50),
                          backgroundColor: const Color(0xFF1C4322),
                        ),
                        child: _isSaving
                            ? const CircularProgressIndicator(color: Colors.white)
                            : Text(
                                widget.isEditing ? 'Update Recipe' : 'Save Recipe',
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _mealTypeController.dispose();
    _complexityController.dispose();
    _prepTimeController.dispose();
    _cookTimeController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatsController.dispose();
    _fiberController.dispose();
    _imageUrlController.dispose();
    _ingredientController.dispose();
    _instructionController.dispose();
    _tagController.dispose();
    _goalTagController.dispose();
    super.dispose();
  }
}
