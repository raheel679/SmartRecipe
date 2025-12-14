// attendance_tracker.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AttendanceTracker {
  final String userId;
  final FirebaseFirestore firestore;

  AttendanceTracker({
    required this.userId,
    required this.firestore,
  });

  Future<AttendanceStatus> checkAttendanceStatus() async {
    try {
      // Get attendance record
      final attendanceDoc = await firestore
          .collection('users')
          .doc(userId)
          .collection('attendance')
          .doc('tracking')
          .get();

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      
      // Default data if no record exists
      Map<String, dynamic> attendanceData = {
        'lastTracked': Timestamp.fromDate(today.subtract(const Duration(days: 1))),
        'trackedDays': [],
        'missedDays': [],
        'currentStreak': 0,
        'longestStreak': 0,
        'lastChecked': Timestamp.now(),
      };

      if (attendanceDoc.exists) {
        attendanceData = attendanceDoc.data()!;
      }

      // Calculate missed days
      final lastTracked = (attendanceData['lastTracked'] as Timestamp).toDate();
      final trackedDays = List<String>.from(attendanceData['trackedDays'] ?? []);
      final missedDays = List<String>.from(attendanceData['missedDays'] ?? []);
      
      // Convert tracked days to DateTime objects
      final trackedDates = trackedDays.map((dateStr) => DateTime.parse(dateStr)).toList();
      
      // Check for missed days since last tracked
      final missedDates = <DateTime>[];
      var checkDate = lastTracked.add(const Duration(days: 1));
      
      while (checkDate.isBefore(today)) {
        final dateStr = _formatDate(checkDate);
        if (!trackedDays.contains(dateStr) && !missedDays.contains(dateStr)) {
          missedDates.add(checkDate);
        }
        checkDate = checkDate.add(const Duration(days: 1));
      }

      // Update streaks
      int currentStreak = attendanceData['currentStreak'] ?? 0;
      int longestStreak = attendanceData['longestStreak'] ?? 0;
      
      // Check if today is tracked
      final todayStr = _formatDate(today);
      final isTodayTracked = trackedDays.contains(todayStr);
      
      if (isTodayTracked) {
        currentStreak++;
      } else if (!missedDates.contains(today)) {
        // If today is not tracked and not marked as missed, check streak
        final yesterday = today.subtract(const Duration(days: 1));
        final yesterdayStr = _formatDate(yesterday);
        
        if (trackedDays.contains(yesterdayStr)) {
          currentStreak++;
        } else {
          currentStreak = 0;
        }
      } else {
        currentStreak = 0;
      }
      
      // Update longest streak
      if (currentStreak > longestStreak) {
        longestStreak = currentStreak;
      }

      return AttendanceStatus(
        lastTracked: lastTracked,
        trackedDays: trackedDates,
        missedDates: missedDates,
        currentStreak: currentStreak,
        longestStreak: longestStreak,
        isTodayTracked: isTodayTracked,
        consecutiveMissedDays: _countConsecutiveMissedDays(missedDates),
      );
    } catch (e) {
      print('Error checking attendance: $e');
      return AttendanceStatus.empty();
    }
  }

  Future<void> markDayAsTracked([DateTime? date]) async {
    try {
      final trackDate = date ?? DateTime.now();
      final dateStr = _formatDate(trackDate);
      
      final attendanceRef = firestore
          .collection('users')
          .doc(userId)
          .collection('attendance')
          .doc('tracking');

      await firestore.runTransaction((transaction) async {
        final doc = await transaction.get(attendanceRef);
        
        Map<String, dynamic> data;
        if (doc.exists) {
          data = doc.data()!;
          
          // Update tracked days
          final trackedDays = List<String>.from(data['trackedDays'] ?? []);
          if (!trackedDays.contains(dateStr)) {
            trackedDays.add(dateStr);
          }
          
          // Remove from missed days if present
          final missedDays = List<String>.from(data['missedDays'] ?? []);
          missedDays.remove(dateStr);
          
          // Update streaks
          int currentStreak = data['currentStreak'] ?? 0;
          final yesterday = trackDate.subtract(const Duration(days: 1));
          final yesterdayStr = _formatDate(yesterday);
          
          if (trackedDays.contains(yesterdayStr) || missedDays.contains(yesterdayStr)) {
            currentStreak++;
          } else {
            currentStreak = 1;
          }
          
          int longestStreak = data['longestStreak'] ?? 0;
          if (currentStreak > longestStreak) {
            longestStreak = currentStreak;
          }
          
          data = {
            ...data,
            'lastTracked': Timestamp.fromDate(trackDate),
            'trackedDays': trackedDays,
            'missedDays': missedDays,
            'currentStreak': currentStreak,
            'longestStreak': longestStreak,
            'lastUpdated': Timestamp.now(),
          };
        } else {
          data = {
            'lastTracked': Timestamp.fromDate(trackDate),
            'trackedDays': [dateStr],
            'missedDays': [],
            'currentStreak': 1,
            'longestStreak': 1,
            'createdAt': Timestamp.now(),
            'lastUpdated': Timestamp.now(),
          };
        }
        
        transaction.set(attendanceRef, data);
      });
      
      // Also update the progress tracking
      await _updateProgressTracking(trackDate);
      
    } catch (e) {
      print('Error marking day as tracked: $e');
      throw Exception('Failed to mark day as tracked: $e');
    }
  }

  Future<void> markDayAsMissed(DateTime date) async {
    try {
      final dateStr = _formatDate(date);
      
      final attendanceRef = firestore
          .collection('users')
          .doc(userId)
          .collection('attendance')
          .doc('tracking');

      await firestore.runTransaction((transaction) async {
        final doc = await transaction.get(attendanceRef);
        
        Map<String, dynamic> data;
        if (doc.exists) {
          data = doc.data()!;
          
          // Update missed days
          final missedDays = List<String>.from(data['missedDays'] ?? []);
          if (!missedDays.contains(dateStr)) {
            missedDays.add(dateStr);
          }
          
          // Remove from tracked days if present (shouldn't happen)
          final trackedDays = List<String>.from(data['trackedDays'] ?? []);
          trackedDays.remove(dateStr);
          
          // Reset streak
          data = {
            ...data,
            'missedDays': missedDays,
            'trackedDays': trackedDays,
            'currentStreak': 0,
            'lastUpdated': Timestamp.now(),
          };
        } else {
          data = {
            'lastTracked': Timestamp.fromDate(date.subtract(const Duration(days: 1))),
            'trackedDays': [],
            'missedDays': [dateStr],
            'currentStreak': 0,
            'longestStreak': 0,
            'createdAt': Timestamp.now(),
            'lastUpdated': Timestamp.now(),
          };
        }
        
        transaction.set(attendanceRef, data);
      });
    } catch (e) {
      print('Error marking day as missed: $e');
      throw Exception('Failed to mark day as missed: $e');
    }
  }

  Future<Map<String, dynamic>> getAttendanceReport(DateTime startDate, DateTime endDate) async {
    try {
      final attendanceDoc = await firestore
          .collection('users')
          .doc(userId)
          .collection('attendance')
          .doc('tracking')
          .get();

      if (!attendanceDoc.exists) {
        return {
          'trackedDays': 0,
          'missedDays': 0,
          'completionRate': 0.0,
          'streaks': [],
          'dailyStatus': {},
        };
      }

      final data = attendanceDoc.data()!;
      final trackedDays = List<String>.from(data['trackedDays'] ?? []);
      final missedDays = List<String>.from(data['missedDays'] ?? []);

      // Calculate daily status for the period
      final dailyStatus = <String, String>{};
      var currentDate = startDate;
      
      while (currentDate.isBefore(endDate) || currentDate.isAtSameMomentAs(endDate)) {
        final dateStr = _formatDate(currentDate);
        
        if (trackedDays.contains(dateStr)) {
          dailyStatus[dateStr] = 'tracked';
        } else if (missedDays.contains(dateStr)) {
          dailyStatus[dateStr] = 'missed';
        } else {
          dailyStatus[dateStr] = 'unknown';
        }
        
        currentDate = currentDate.add(const Duration(days: 1));
      }

      // Calculate completion rate
      final totalDays = trackedDays.length + missedDays.length;
      final completionRate = totalDays > 0 ? trackedDays.length / totalDays : 0.0;

      // Identify streaks
      final streaks = _identifyStreaks(trackedDays);

      return {
        'trackedDays': trackedDays.length,
        'missedDays': missedDays.length,
        'completionRate': completionRate,
        'currentStreak': data['currentStreak'] ?? 0,
        'longestStreak': data['longestStreak'] ?? 0,
        'streaks': streaks,
        'dailyStatus': dailyStatus,
        'lastUpdated': data['lastUpdated'],
      };
    } catch (e) {
      print('Error getting attendance report: $e');
      return {
        'trackedDays': 0,
        'missedDays': 0,
        'completionRate': 0.0,
        'streaks': [],
        'dailyStatus': {},
        'error': e.toString(),
      };
    }
  }

  Future<void> sendMissedDayNotification(List<DateTime> missedDates) async {
    // Implement notification logic
    // This could use Firebase Cloud Messaging or local notifications
    print('Sending notification for ${missedDates.length} missed days');
  }

  // Helper methods
  String _formatDate(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  int _countConsecutiveMissedDays(List<DateTime> missedDates) {
    if (missedDates.isEmpty) return 0;
    
    missedDates.sort();
    int maxConsecutive = 1;
    int currentConsecutive = 1;
    
    for (int i = 1; i < missedDates.length; i++) {
      final prevDate = missedDates[i - 1];
      final currentDate = missedDates[i];
      
      if (currentDate.difference(prevDate).inDays == 1) {
        currentConsecutive++;
        if (currentConsecutive > maxConsecutive) {
          maxConsecutive = currentConsecutive;
        }
      } else {
        currentConsecutive = 1;
      }
    }
    
    return maxConsecutive;
  }

  List<Map<String, dynamic>> _identifyStreaks(List<String> trackedDays) {
    final streaks = <Map<String, dynamic>>[];
    
    if (trackedDays.isEmpty) return streaks;
    
    // Convert to DateTime and sort
    final dates = trackedDays.map((d) => DateTime.parse(d)).toList();
    dates.sort();
    
    List<DateTime> currentStreak = [dates.first];
    
    for (int i = 1; i < dates.length; i++) {
      final prevDate = dates[i - 1];
      final currentDate = dates[i];
      
      if (currentDate.difference(prevDate).inDays == 1) {
        currentStreak.add(currentDate);
      } else {
        if (currentStreak.length >= 2) {
          streaks.add({
            'start': currentStreak.first,
            'end': currentStreak.last,
            'length': currentStreak.length,
          });
        }
        currentStreak = [currentDate];
      }
    }
    
    // Add the last streak
    if (currentStreak.length >= 2) {
      streaks.add({
        'start': currentStreak.first,
        'end': currentStreak.last,
        'length': currentStreak.length,
      });
    }
    
    return streaks;
  }

  Future<void> _updateProgressTracking(DateTime date) async {
    try {
      final progressRef = firestore
          .collection('users')
          .doc(userId)
          .collection('progress')
          .doc('current_week');

      await firestore.runTransaction((transaction) async {
        final doc = await transaction.get(progressRef);
        
        if (doc.exists) {
          final data = doc.data()!;
          final completedDays = List<String>.from(data['completedDays'] ?? []);
          
          final dayName = DateFormat('EEEE').format(date);
          if (!completedDays.contains(dayName)) {
            completedDays.add(dayName);
            
            transaction.update(progressRef, {
              'completedDays': completedDays,
              'lastUpdated': Timestamp.now(),
            });
          }
        }
      });
    } catch (e) {
      print('Error updating progress tracking: $e');
    }
  }
}

class AttendanceStatus {
  final DateTime lastTracked;
  final List<DateTime> trackedDays;
  final List<DateTime> missedDates;
  final int currentStreak;
  final int longestStreak;
  final bool isTodayTracked;
  final int consecutiveMissedDays;

  AttendanceStatus({
    required this.lastTracked,
    required this.trackedDays,
    required this.missedDates,
    required this.currentStreak,
    required this.longestStreak,
    required this.isTodayTracked,
    required this.consecutiveMissedDays,
  });

  factory AttendanceStatus.empty() {
    final now = DateTime.now();
    return AttendanceStatus(
      lastTracked: now.subtract(const Duration(days: 1)),
      trackedDays: [],
      missedDates: [],
      currentStreak: 0,
      longestStreak: 0,
      isTodayTracked: false,
      consecutiveMissedDays: 0,
    );
  }

  int get missedDays => missedDates.length;
  
  int get totalMissedDays => missedDates.length;
  
  bool get requiresAlert {
    if (missedDates.isEmpty) return false;
    
    // Alert if missed yesterday or missed 2+ consecutive days
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final missedYesterday = missedDates.any((date) => 
      date.year == yesterday.year &&
      date.month == yesterday.month &&
      date.day == yesterday.day
    );
    
    return missedYesterday || consecutiveMissedDays >= 2;
  }
  
  List<String> get missedDatesFormatted {
    return missedDates.map((date) => DateFormat('MMM d').format(date)).toList();
  }
}
