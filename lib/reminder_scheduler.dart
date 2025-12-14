import 'NotificationService.dart';
class ReminderScheduler {
  final NotificationService _notificationService = NotificationService();

  // Schedule reminders for entire weekly plan
  Future<void> scheduleWeeklyReminders(Map<String, dynamic> weeklyPlan) async {
    print('📅 Scheduling weekly reminders...');
    
    // Clear existing reminders first
    await _notificationService.cancelAllNotifications();

    final days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    
    // Schedule grocery reminder for Sunday
    await _notificationService.scheduleGroceryReminder('Sunday');

    // Schedule meal reminders for each day
    for (final day in days) {
      final dayData = weeklyPlan[day] as Map<String, dynamic>?;
      if (dayData != null) {
        await _scheduleDayReminders(day, dayData);
      }
    }

    // Show confirmation notification
    await _notificationService.showInstantNotification(
      title: '📋 Weekly Plan Scheduled!',
      body: 'Your meal reminders for the week have been set up.',
      payload: 'weekly_plan_scheduled',
    );

    print('✅ All weekly reminders scheduled successfully');
  }

  // Schedule reminders for a specific day
  Future<void> _scheduleDayReminders(String day, Map<String, dynamic> dayData) async {
    final meals = dayData['meals'] as Map<String, dynamic>;
    final mealTimes = _getDefaultMealTimes(day);
    
    for (final mealEntry in meals.entries) {
      final mealType = mealEntry.key;
      final recipe = mealEntry.value as Map<String, dynamic>;
      final mealTime = mealTimes[mealType];
      
      if (mealTime != null) {
        // Schedule meal prep reminder (30 mins before)
        await _notificationService.scheduleMealPrepReminder(recipe, mealTime);
        
        // Schedule actual meal time notification
        await _notificationService.scheduleMealTimeNotification(mealType, recipe, mealTime);
      }
    }

    print('✅ Scheduled reminders for $day');
  }


  

  // Get default meal times for a day
  Map<String, DateTime> _getDefaultMealTimes(String day) {
    final now = DateTime.now();
    final dayOffset = _getDayOffset(day);
    final targetDate = now.add(Duration(days: dayOffset));
    
    return {
      'Breakfast': DateTime(targetDate.year, targetDate.month, targetDate.day, 8, 0),
      'Lunch': DateTime(targetDate.year, targetDate.month, targetDate.day, 13, 0),
      'Dinner': DateTime(targetDate.year, targetDate.month, targetDate.day, 19, 0),
      'Snack': DateTime(targetDate.year, targetDate.month, targetDate.day, 16, 0),
    };
  }

  // Calculate days until target day
  int _getDayOffset(String day) {
    final today = DateTime.now().weekday;
    final targetDay = _parseWeekday(day);
    return (targetDay - today) % 7;
  }

  int _parseWeekday(String day) {
    const days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    return days.indexWhere((d) => d.toLowerCase() == day.toLowerCase()) + 1;
  }

  // Update reminders when meal is swapped
  Future<void> updateMealReminder(
    String day, 
    String mealType, 
    Map<String, dynamic> newRecipe,
  ) async {
    final mealTimes = _getDefaultMealTimes(day);
    final mealTime = mealTimes[mealType];
    
    if (mealTime != null) {
      // Cancel old reminders (if any)
      // Note: You'd need to track old recipe IDs to cancel them
      
      // Schedule new reminders
      await _notificationService.scheduleMealPrepReminder(newRecipe, mealTime);
      await _notificationService.scheduleMealTimeNotification(mealType, newRecipe, mealTime);
      
      print('🔄 Updated reminders for $day $mealType');
    }
  }

  // Cancel all reminders (when user regenerates plan or logs out)
  Future<void> cancelAllReminders() async {
    await _notificationService.cancelAllNotifications();
    print('🗑️ All meal reminders cancelled');
  }

  // Debug method to show pending notifications
  Future<void> debugShowPendingNotifications() async {
    final pending = await _notificationService.getPendingNotifications();
    print('📋 Pending notifications: ${pending.length}');
    for (final notification in pending) {
      print('  - ${notification.title} at ${notification.body}');
    }
  }
}
