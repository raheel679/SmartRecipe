import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MissedDaysAlert extends StatelessWidget {
  final List<DateTime> missedDates;
  final int consecutiveMissedDays;
  final int currentStreak;
  final VoidCallback onMarkToday;
  final VoidCallback onScheduleReminders;
  final VoidCallback onViewDetails;
  final Function(List<DateTime>)? onCatchUp;

  const MissedDaysAlert({
    super.key,
    required this.missedDates,
    required this.consecutiveMissedDays,
    required this.currentStreak,
    required this.onMarkToday,
    required this.onScheduleReminders,
    required this.onViewDetails,
    this.onCatchUp,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  consecutiveMissedDays >= 3 
                      ? Icons.warning_amber 
                      : Icons.notifications_active,
                  color: consecutiveMissedDays >= 3 ? Colors.orange : Colors.blue,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Missed ${missedDates.length} Day${missedDates.length > 1 ? 's' : ''}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Message
            Text(
              _getMessage(),
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
                height: 1.5,
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Missed dates if few
            if (missedDates.isNotEmpty && missedDates.length <= 5)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Missed on:',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...missedDates.map((date) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(
                          Icons.circle,
                          size: 8,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat('EEEE, MMMM d').format(date),
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  )),
                  const SizedBox(height: 20),
                ],
              ),
            
            // Current streak info
            if (currentStreak > 0)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.local_fire_department,
                      color: Colors.orange.shade700,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'You have a $currentStreak-day streak! Don\'t break it!',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.orange.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            
            const SizedBox(height: 20),
            
            // Action buttons
            Column(
              children: [
                // Primary action - Mark Today
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      onMarkToday();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle),
                        SizedBox(width: 8),
                        Text(
                          'Mark Today as Completed',
                          style: TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // Secondary actions row
                Row(
                  children: [
                    // Catch up button (only if missed dates)
                    if (missedDates.isNotEmpty && onCatchUp != null)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            onCatchUp!(missedDates);
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
  Icon(Icons.cached),   // <-- correct icon
  SizedBox(width: 4),
  Text('Catch Up'),
]

                          ),
                        ),
                      ),
                    
                    if (missedDates.isNotEmpty && onCatchUp != null)
                      const SizedBox(width: 8),
                    
                    // Reminders button
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          onScheduleReminders();
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.notifications),
                            SizedBox(width: 4),
                            Text('Reminders'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 8),
                
                // View details button
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    onViewDetails();
                  },
                  child: const Text('View Detailed Report'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getMessage() {
    if (consecutiveMissedDays >= 3) {
      return 'You\'ve missed $consecutiveMissedDays consecutive days. Consistency is key to achieving your health goals!';
    } else if (missedDates.length > 3) {
      return 'You\'ve missed several tracking sessions this week. Regular tracking helps you stay on course.';
    } else if (currentStreak > 0) {
      return 'You have a $currentStreak-day streak going! Don\'t let today break it.';
    } else {
      return 'We noticed you missed tracking your meals. Would you like to mark today as completed?';
    }
  }
}
