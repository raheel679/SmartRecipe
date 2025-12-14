
// lib/services/notification_service.dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzData;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  late FlutterLocalNotificationsPlugin _notifications;
  bool _initialized = false;

  /// Public initialize that must be called at app start
  Future<void> initialize() async {
    if (kIsWeb) {
      _initialized = true;
      debugPrint('⚠️ Notifications: Web platform - initialization skipped.');
      return;
    }

    if (_initialized) return;

    _notifications = FlutterLocalNotificationsPlugin();

    // Timezone initialization
    tzData.initializeTimeZones();

    // Android initialization
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS / macOS initialization
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    try {
      await _notifications.initialize(
        settings,
        onDidReceiveNotificationResponse: _onDidReceiveNotificationResponse,
      );

      // Create Android channels
      await _createNotificationChannels();

      _initialized = true;
      debugPrint('✅ NotificationService initialized successfully');
    } catch (e) {
      debugPrint('❌ Error initializing notifications: $e');
    }
  }

  // Ensure plugin is initialized before usage
  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await initialize();
  }

  Future<void> _createNotificationChannels() async {
    if (kIsWeb) return;

    try {
      const AndroidNotificationChannel mealPrepChannel = AndroidNotificationChannel(
        'meal_prep_channel',
        'Meal Prep Reminders',
        description: 'Notifications for meal preparation times',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );

      const AndroidNotificationChannel mealTimeChannel = AndroidNotificationChannel(
        'meal_time_channel',
        'Meal Time Reminders',
        description: 'Notifications for scheduled meal times',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );

      final androidPlugin = _notifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

      await androidPlugin?.createNotificationChannel(mealPrepChannel);
      await androidPlugin?.createNotificationChannel(mealTimeChannel);
    } catch (e) {
      debugPrint('❌ Error creating notification channels: $e');
    }
  }

  static void _onDidReceiveNotificationResponse(NotificationResponse response) {
    debugPrint('🔔 Notification tapped: ${response.payload}');
  }

  // ---------------- Request Permissions ----------------
  
  Future<bool> requestPermissions() async {
    if (kIsWeb) {
      debugPrint('⚠️ Permission request skipped on Web platform');
      return false;
    }

    await _ensureInitialized();

    try {
      // Request permissions for iOS
      final iOSPlugin = _notifications
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      
     if (iOSPlugin != null) {
  try {
    await iOSPlugin.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('✅ iOS notifications permission requested (assume granted)');
    return true; // assume granted if no exception
  } catch (e) {
    debugPrint('❌ iOS notifications permission request failed: $e');
    return false;
  }
}


      // For Android, permissions are handled differently (API 33+)
      debugPrint('✅ Android notifications enabled');
      return true;
    } catch (e) {
      debugPrint('❌ Error requesting notification permissions: $e');
      return false;
    }
  }

  // ---------------- Scheduling Methods ----------------

  Future<void> scheduleMealPrepReminder(
    Map<String, dynamic> recipe,
    DateTime mealTime,
  ) async {
    if (kIsWeb) {
      debugPrint('⚠️ scheduleMealPrepReminder skipped on Web: ${recipe['name']}');
      return;
    }

    await _ensureInitialized();

    try {
      final totalTime = recipe['totalTime'] as int? ?? 30;
      final reminderTime = mealTime.subtract(const Duration(minutes: 30));

      if (reminderTime.isBefore(DateTime.now())) {
        debugPrint('⏳ Reminder time is in the past: $reminderTime');
        return;
      }

      final recipeName = recipe['name']?.toString() ?? 'Your meal';
      final recipeId = recipe['id']?.toString() ?? recipe.hashCode.toString();

      await _notifications.zonedSchedule(
        _generateNotificationId(recipeId, 'prep'),
        'Time to Start Cooking! 🍳',
        'Prepare $recipeName. Total time: $totalTime minutes.',
        tz.TZDateTime.from(reminderTime, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'meal_prep_channel',
            'Meal Prep Reminders',
            channelDescription: 'Reminders for meal preparation',
            importance: Importance.high,
            priority: Priority.high,
            enableVibration: true,
            colorized: true,
            color: Color(0xFF1C4322),
          ),
          iOS: DarwinNotificationDetails(
            sound: 'default',
            badgeNumber: 1,
          ),
        ),
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'meal_prep|$recipeId',
      );

      debugPrint('✅ Scheduled prep reminder for "$recipeName" at $reminderTime');
    } catch (e) {
      debugPrint('❌ Error scheduling meal prep reminder: $e');
    }
  }

  Future<void> scheduleMealTimeNotification(
    String mealType,
    Map<String, dynamic> recipe,
    DateTime mealTime,
  ) async {
    if (kIsWeb) {
      debugPrint('⚠️ scheduleMealTimeNotification skipped on Web: $mealType ${recipe['name']}');
      return;
    }

    await _ensureInitialized();

    try {
      final recipeName = recipe['name']?.toString() ?? 'Your meal';
      final recipeId = recipe['id']?.toString() ?? recipe.hashCode.toString();

      await _notifications.zonedSchedule(
        _generateNotificationId(recipeId, 'meal'),
        '$mealType Time! 🍽️',
        'Time for $recipeName — enjoy your meal!',
        tz.TZDateTime.from(mealTime, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'meal_time_channel',
            'Meal Time Reminders',
            channelDescription: 'Notifications for scheduled meal times',
            importance: Importance.max,
            priority: Priority.high,
            enableVibration: true,
            colorized: true,
            color: Color(0xFF1C4322),
          ),
          iOS: DarwinNotificationDetails(
            sound: 'default',
            badgeNumber: 1,
          ),
        ),
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'meal_time|$recipeId|$mealType',
      );

      debugPrint('✅ Scheduled $mealType notification at $mealTime');
    } catch (e) {
      debugPrint('❌ Error scheduling meal time notification: $e');
    }
  }

  Future<void> scheduleGroceryReminder(String day) async {
    if (kIsWeb) {
      debugPrint('⚠️ scheduleGroceryReminder skipped on Web: $day');
      return;
    }

    await _ensureInitialized();

    try {
      final reminderTime = _getGroceryReminderTime(day);

      if (reminderTime.isBefore(DateTime.now())) {
        debugPrint('⏳ Grocery reminder time in past: $reminderTime');
        return;
      }

      await _notifications.zonedSchedule(
        _generateNotificationId('grocery', day),
        'Grocery Shopping Reminder 🛒',
        'Time to shop for ingredients for your $day meals!',
        tz.TZDateTime.from(reminderTime, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'meal_prep_channel',
            'Meal Prep Reminders',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(
            sound: 'default',
            badgeNumber: 1,
          ),
        ),
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'grocery_reminder|$day',
      );

      debugPrint('✅ Scheduled grocery reminder for $day at $reminderTime');
    } catch (e) {
      debugPrint('❌ Error scheduling grocery reminder: $e');
    }
  }

  // ---------------- Daily Meal Reminders ----------------

  Future<void> scheduleDailyNotification({
    required String title,
    required String body,
    required TimeOfDay time,
    String? payload,
  }) async {
    if (kIsWeb) {
      debugPrint('⚠️ scheduleDailyNotification skipped on Web: $title');
      return;
    }

    await _ensureInitialized();

    try {
      final now = DateTime.now();
      final scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        time.hour,
        time.minute,
      );

      // If the time is already past for today, schedule for tomorrow
      final notificationTime = scheduledDate.isBefore(now)
          ? scheduledDate.add(const Duration(days: 1))
          : scheduledDate;

      await _notifications.zonedSchedule(
        _generateDailyNotificationId(time),
        title,
        body,
        notificationTime,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'meal_time_channel',
            'Meal Time Reminders',
            importance: Importance.max,
            priority: Priority.high,
            colorized: true,
            color: Color(0xFF1C4322),
            enableVibration: true,
          ),
          iOS: DarwinNotificationDetails(
            sound: 'default',
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: payload,
      );

      debugPrint('✅ Scheduled daily notification for ${_formatTime(time)}');
    } catch (e) {
      debugPrint('❌ Error scheduling daily notification: $e');
    }
  }

  

  // ---------------- Instant Notifications ----------------

  Future<void> showInstantNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (kIsWeb) {
      debugPrint('⚠️ showInstantNotification skipped on Web: $title');
      return;
    }

    await _ensureInitialized();

    try {
      await _notifications.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'meal_prep_channel',
            'Meal Prep Reminders',
            importance: Importance.high,
            priority: Priority.high,
            colorized: true,
            color: Color(0xFF1C4322),
          ),
          iOS: DarwinNotificationDetails(
            sound: 'default',
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: payload,
      );

      debugPrint('✅ Instant notification shown: $title');
    } catch (e) {
      debugPrint('❌ Error showing instant notification: $e');
    }
  }

  Future<void> showDayCompletionNotification(String dayName) async {
    await showInstantNotification(
      title: 'Day Completed! 🎉',
      body: 'Great job! You completed $dayName successfully.',
      payload: 'day_completed|$dayName',
    );
  }

  Future<void> showCookingReminderNotification(String recipeName) async {
    await showInstantNotification(
      title: 'Time to Cook! ⏰',
      body: 'Don\'t forget to prepare $recipeName today.',
      payload: 'cooking_reminder',
    );
  }

  Future<void> showWeekCompletionNotification(int weekNumber) async {
    await showInstantNotification(
      title: 'Week Completed! 🏆',
      body: 'Congratulations! You completed Week $weekNumber successfully.',
      payload: 'week_completed|$weekNumber',
    );
  }

  Future<void> showTestNotification() async {
    await showInstantNotification(
      title: 'Test Notification ✅',
      body: 'This is a test notification to verify notification functionality.',
      payload: 'test_notification',
    );
  }

  // ---------------- Cancellation Methods ----------------

  Future<void> cancelNotification(int id) async {
    if (kIsWeb) return;
    await _ensureInitialized();
    
    try {
      await _notifications.cancel(id);
      debugPrint('🗑️ Cancelled notification: $id');
    } catch (e) {
      debugPrint('❌ Error cancelling notification: $e');
    }
  }

  Future<void> cancelAllNotifications() async {
    if (kIsWeb) {
      debugPrint('⚠️ cancelAllNotifications skipped on Web.');
      return;
    }
    
    await _ensureInitialized();
    
    try {
      await _notifications.cancelAll();
      debugPrint('🗑️ All notifications cancelled');
    } catch (e) {
      debugPrint('❌ Error cancelling all notifications: $e');
    }
  }

  Future<void> cancelRecipeNotifications(String recipeId) async {
    if (kIsWeb) return;
    
    await _ensureInitialized();
    
    try {
      final prepId = _generateNotificationId(recipeId, 'prep');
      final mealId = _generateNotificationId(recipeId, 'meal');
      await _notifications.cancel(prepId);
      await _notifications.cancel(mealId);
      debugPrint('🗑️ Cancelled all notifications for recipe: $recipeId');
    } catch (e) {
      debugPrint('❌ Error cancelling recipe notifications: $e');
    }
  }

  // ---------------- Utility Methods ----------------

  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    if (kIsWeb) return <PendingNotificationRequest>[];
    
    await _ensureInitialized();
    
    try {
      return await _notifications.pendingNotificationRequests();
    } catch (e) {
      debugPrint('❌ Error getting pending notifications: $e');
      return [];
    }
  }

  int _generateNotificationId(String recipeId, String type) {
    return (recipeId.hashCode.abs() + type.hashCode.abs()) % 100000;
  }

  int _generateDailyNotificationId(TimeOfDay time) {
    return (time.hour * 100 + time.minute).hashCode.abs() % 100000;
  }

  DateTime _getGroceryReminderTime(String day) {
    final now = DateTime.now();
    final targetDay = _parseWeekday(day);
    final diff = (targetDay - now.weekday) % 7;
    final targetDate = now.add(Duration(days: diff));
    return DateTime(targetDate.year, targetDate.month, targetDate.day, 9, 0);
  }

  int _parseWeekday(String day) {
    const days = [
      'Sunday',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday'
    ];
    return days.indexWhere((d) => d.toLowerCase() == day.toLowerCase()) + 1;
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
