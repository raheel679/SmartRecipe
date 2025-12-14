// daily_feedback.dart
import 'package:flutter/material.dart';

class DailyFeedback extends StatefulWidget {
  final Map<String, dynamic> dailyMeals;
  final Function(int rating, String comment, Map<String, dynamic> recipe) onFeedbackSubmitted;

  const DailyFeedback({
    super.key,
    required this.dailyMeals,
    required this.onFeedbackSubmitted,
  });

  @override
  State<DailyFeedback> createState() => _DailyFeedbackState();
}

class _DailyFeedbackState extends State<DailyFeedback> {
  final Map<String, int> _mealRatings = {};
  final Map<String, String> _mealComments = {};
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    final meals = widget.dailyMeals['meals'] as Map<String, dynamic>? ?? {};

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.feedback, color: Colors.blue),
          SizedBox(width: 8),
          Text('Daily Feedback'),
        ],
      ),
      content: SingleChildScrollView(
        child: _isSubmitting
            ? _buildLoadingContent()
            : _buildFeedbackContent(meals),
      ),
      actions: _isSubmitting
          ? []
          : _buildDialogActions(meals),
    );
  }

  Widget _buildLoadingContent() {
    return SizedBox(
      height: 200,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Submitting your feedback...',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedbackContent(Map<String, dynamic> meals) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'How was your food today?',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        const Text(
          'Rate each meal and share your thoughts to help us improve your plan.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 20),
        ...meals.entries.map((entry) {
          final mealType = entry.key;
          final recipe = entry.value as Map<String, dynamic>;
          
          return _buildMealRatingSection(mealType, recipe);
        }).toList(),
      ],
    );
  }

  Widget _buildMealRatingSection(String mealType, Map<String, dynamic> recipe) {
    final currentRating = _mealRatings[mealType] ?? 0;
    final currentComment = _mealComments[mealType] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$mealType: ${recipe['name'] ?? 'Meal'}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text('Rating:', style: TextStyle(fontSize: 12)),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              return IconButton(
                icon: Icon(
                  index < currentRating ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                  size: 24,
                ),
                onPressed: () {
                  setState(() {
                    _mealRatings[mealType] = index + 1;
                  });
                },
              );
            }),
          ),
          const SizedBox(height: 8),
          TextField(
            decoration: InputDecoration(
              labelText: 'Comments (optional)',
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.all(12),
              hintText: 'Any feedback on this meal?',
              hintStyle: TextStyle(color: Colors.grey.shade400),
            ),
            maxLines: 2,
            onChanged: (value) {
              _mealComments[mealType] = value;
            },
          ),
        ],
      ),
    );
  }

  List<Widget> _buildDialogActions(Map<String, dynamic> meals) {
    final allRated = meals.keys.every((mealType) => _mealRatings.containsKey(mealType));

    return [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Skip'),
      ),
      ElevatedButton(
        onPressed: allRated ? _submitFeedback : null,
        child: const Text('Submit Feedback'),
      ),
    ];
  }

  Future<void> _submitFeedback() async {
    setState(() {
      _isSubmitting = true;
    });

    try {
      final meals = widget.dailyMeals['meals'] as Map<String, dynamic>? ?? {};
      
      for (final entry in meals.entries) {
        final mealType = entry.key;
        final recipe = entry.value as Map<String, dynamic>;
        final rating = _mealRatings[mealType] ?? 0;
        final comment = _mealComments[mealType] ?? '';

        if (rating > 0) {
          await widget.onFeedbackSubmitted(rating, comment, recipe);
        }
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Thanks for your feedback!'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting feedback: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }
}