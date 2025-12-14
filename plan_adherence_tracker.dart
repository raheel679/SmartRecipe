import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AttendanceTracker {
  final String userId;
  final FirebaseFirestore firestore;

  AttendanceTracker({
    required this.userId,
    required this.firestore,
  });

  // Check if today is already tracked
  Future<bool> isTodayTracked() async {
    try {
      final today = _formatDate(DateTime.now());
      final attendanceDoc = await firestore
          .collection('users')
          .doc(userId)
          .collection('attendance')
          .doc('tracking')
          .get();

      if (!attendanceDoc.exists) return false;

      final data = attendanceDoc.data()!;
      final trackedDays = List<String>.from(data['trackedDays'] ?? []);
      
      return trackedDays.contains(today);
    } catch (e) {
      print('Error checking if today is tracked: $e');
      return false;
    }
  }

  // Mark a day as tracked
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
          
          // Calculate streaks
          int currentStreak = data['currentStreak'] ?? 0;
          final yesterday = trackDate.subtract(const Duration(days: 1));
          final yesterdayStr = _formatDate(yesterday);
          
          if (trackedDays.contains(yesterdayStr)) {
            currentStreak++;
          } else {
            currentStreak = 1;
          }
          
          int longestStreak = data['longestStreak'] ?? 0;
          if (currentStreak > longestStreak) {
            longestStreak = currentStreak;
          }
          
          // Prepare update data
          final updateData = {
            'lastTracked': Timestamp.fromDate(trackDate),
            'trackedDays': trackedDays,
            'missedDays': missedDays,
            'currentStreak': currentStreak,
            'longestStreak': longestStreak,
            'lastUpdated': Timestamp.now(),
          };
          
          transaction.update(attendanceRef, updateData);
        } else {
          // Create new document
          data = {
            'userId': userId,
            'lastTracked': Timestamp.fromDate(trackDate),
            'trackedDays': [dateStr],
            'missedDays': [],
            'currentStreak': 1,
            'longestStreak': 1,
            'createdAt': Timestamp.now(),
            'lastUpdated': Timestamp.now(),
          };
          transaction.set(attendanceRef, data);
        }
      });
      
      // Also update the progress tracking
      await _updateProgressTracking(trackDate);
      
    } catch (e) {
      print('Error marking day as tracked: $e');
      throw Exception('Failed to mark day as tracked: $e');
    }
  }

  // Mark a day as missed
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
          
          // Remove from tracked days if present
          final trackedDays = List<String>.from(data['trackedDays'] ?? []);
          trackedDays.remove(dateStr);
          
          // Reset streak if missed yesterday
          int currentStreak = data['currentStreak'] ?? 0;
          final yesterday = date.subtract(const Duration(days: 1));
          final yesterdayStr = _formatDate(yesterday);
          
          if (trackedDays.contains(yesterdayStr)) {
            // Keep streak if missed day is not consecutive
          } else {
            currentStreak = 0;
          }
          
          final updateData = {
            'missedDays': missedDays,
            'trackedDays': trackedDays,
            'currentStreak': currentStreak,
            'lastUpdated': Timestamp.now(),
          };
          
          transaction.update(attendanceRef, updateData);
        } else {
          data = {
            'userId': userId,
            'lastTracked': Timestamp.fromDate(date.subtract(const Duration(days: 1))),
            'trackedDays': [],
            'missedDays': [dateStr],
            'currentStreak': 0,
            'longestStreak': 0,
            'createdAt': Timestamp.now(),
            'lastUpdated': Timestamp.now(),
          };
          transaction.set(attendanceRef, data);
        }
      });
    } catch (e) {
      print('Error marking day as missed: $e');
      throw Exception('Failed to mark day as missed: $e');
    }
  }

  // Check attendance status and get missed days
  Future<AttendanceStatus> checkAttendanceStatus() async {
    try {
      final attendanceDoc = await firestore
          .collection('users')
          .doc(userId)
          .collection('attendance')
          .doc('tracking')
          .get();

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      
      if (!attendanceDoc.exists) {
        return AttendanceStatus(
          lastTracked: today.subtract(const Duration(days: 1)),
          trackedDays: [],
          missedDates: [],
          currentStreak: 0,
          longestStreak: 0,
          isTodayTracked: false,
          consecutiveMissedDays: 0,
        );
      }

      final data = attendanceDoc.data()!;
      final lastTracked = (data['lastTracked'] as Timestamp).toDate();
      final trackedDays = List<String>.from(data['trackedDays'] ?? []);
      final missedDays = List<String>.from(data['missedDays'] ?? []);
      
      // Calculate missed dates since last tracked
      final missedDates = <DateTime>[];
      var checkDate = lastTracked.add(const Duration(days: 1));
      final todayStr = _formatDate(today);
      
      while (checkDate.isBefore(today)) {
        final dateStr = _formatDate(checkDate);
        if (!trackedDays.contains(dateStr) && !missedDays.contains(dateStr)) {
          missedDates.add(checkDate);
        }
        checkDate = checkDate.add(const Duration(days: 1));
      }

      // Check if today is tracked
      final isTodayTracked = trackedDays.contains(todayStr);
      
      // Get streaks
      final currentStreak = data['currentStreak'] ?? 0;
      final longestStreak = data['longestStreak'] ?? 0;
      
      // Calculate consecutive missed days
      final consecutiveMissedDays = _countConsecutiveMissedDays(missedDates);

      return AttendanceStatus(
        lastTracked: lastTracked,
        trackedDays: trackedDays.map((d) => DateTime.parse(d)).toList(),
        missedDates: missedDates,
        currentStreak: currentStreak,
        longestStreak: longestStreak,
        isTodayTracked: isTodayTracked,
        consecutiveMissedDays: consecutiveMissedDays,
      );
    } catch (e) {
      print('Error checking attendance: $e');
      return AttendanceStatus.empty();
    }
  }

  // Get attendance statistics for a period
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
          'currentStreak': 0,
          'longestStreak': 0,
          'streaks': [],
          'dailyStatus': {},
          'totalDays': 0,
        };
      }

      final data = attendanceDoc.data()!;
      final trackedDays = List<String>.from(data['trackedDays'] ?? []);
      final missedDays = List<String>.from(data['missedDays'] ?? []);

      // Calculate daily status for the period
      final dailyStatus = <String, String>{};
      var currentDate = DateTime(startDate.year, startDate.month, startDate.day);
      final end = DateTime(endDate.year, endDate.month, endDate.day);
      int totalDays = 0;
      
      while (currentDate.isBefore(end) || currentDate.isAtSameMomentAs(end)) {
        final dateStr = _formatDate(currentDate);
        totalDays++;
        
        if (trackedDays.contains(dateStr)) {
          dailyStatus[dateStr] = 'tracked';
        } else if (missedDays.contains(dateStr)) {
          dailyStatus[dateStr] = 'missed';
        } else {
          dailyStatus[dateStr] = 'pending';
        }
        
        currentDate = currentDate.add(const Duration(days: 1));
      }

      // Calculate completion rate (only for days that have passed)
      final now = DateTime.now();
      final daysPassed = dailyStatus.keys.where((dateStr) {
        final date = DateTime.parse(dateStr);
        return date.isBefore(now);
      }).length;
      
      final trackedInPeriod = dailyStatus.values.where((status) => status == 'tracked').length;
      final completionRate = daysPassed > 0 ? trackedInPeriod / daysPassed : 0.0;

      // Identify streaks
      final streaks = _identifyStreaks(trackedDays);

      return {
        'trackedDays': trackedInPeriod,
        'missedDays': dailyStatus.values.where((status) => status == 'missed').length,
        'completionRate': completionRate,
        'currentStreak': data['currentStreak'] ?? 0,
        'longestStreak': data['longestStreak'] ?? 0,
        'streaks': streaks,
        'dailyStatus': dailyStatus,
        'totalDays': totalDays,
        'daysPassed': daysPassed,
        'lastUpdated': data['lastUpdated'],
      };
    } catch (e) {
      print('Error getting attendance report: $e');
      return {
        'trackedDays': 0,
        'missedDays': 0,
        'completionRate': 0.0,
        'currentStreak': 0,
        'longestStreak': 0,
        'streaks': [],
        'dailyStatus': {},
        'totalDays': 0,
        'daysPassed': 0,
        'error': e.toString(),
      };
    }
  }

  // Get weekly summary
  Future<WeeklyAttendanceSummary> getWeeklySummary() async {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));
    
    final report = await getAttendanceReport(startOfWeek, endOfWeek);
    
    return WeeklyAttendanceSummary(
      weekStart: startOfWeek,
      weekEnd: endOfWeek,
      trackedDays: report['trackedDays'] ?? 0,
      missedDays: report['missedDays'] ?? 0,
      completionRate: report['completionRate'] ?? 0.0,
      currentStreak: report['currentStreak'] ?? 0,
      longestStreak: report['longestStreak'] ?? 0,
      totalDays: report['totalDays'] ?? 7,
      daysPassed: report['daysPassed'] ?? 0,
    );
  }

  // Batch update multiple days
  Future<void> batchUpdateDays(List<DateTime> dates, bool tracked) async {
    for (final date in dates) {
      if (tracked) {
        await markDayAsTracked(date);
      } else {
        await markDayAsMissed(date);
      }
    }
  }

  // Helper methods
  String _formatDate(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  int _countConsecutiveMissedDays(List<DateTime> missedDates) {
    if (missedDates.isEmpty) return 0;
    
    final sortedDates = List<DateTime>.from(missedDates)..sort();
    int maxConsecutive = 1;
    int currentConsecutive = 1;
    
    for (int i = 1; i < sortedDates.length; i++) {
      final prevDate = sortedDates[i - 1];
      final currentDate = sortedDates[i];
      
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
          
          final dayName = DateFormat('EEEE').format(date).toLowerCase();
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

  // Reset attendance (for testing or account reset)
  Future<void> resetAttendance() async {
    try {
      final attendanceRef = firestore
          .collection('users')
          .doc(userId)
          .collection('attendance')
          .doc('tracking');

      await attendanceRef.delete();
    } catch (e) {
      print('Error resetting attendance: $e');
      throw Exception('Failed to reset attendance: $e');
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
    
    // Alert if missed yesterday or missed 3+ consecutive days
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final missedYesterday = missedDates.any((date) => 
      date.year == yesterday.year &&
      date.month == yesterday.month &&
      date.day == yesterday.day
    );
    
    return missedYesterday || consecutiveMissedDays >= 3;
  }
  
  List<String> get missedDatesFormatted {
    return missedDates.map((date) => DateFormat('MMM d').format(date)).toList();
  }
  
  String get lastTrackedFormatted {
    return DateFormat('MMM d, yyyy').format(lastTracked);
  }
}

class WeeklyAttendanceSummary {
  final DateTime weekStart;
  final DateTime weekEnd;
  final int trackedDays;
  final int missedDays;
  final double completionRate;
  final int currentStreak;
  final int longestStreak;
  final int totalDays;
  final int daysPassed;

  WeeklyAttendanceSummary({
    required this.weekStart,
    required this.weekEnd,
    required this.trackedDays,
    required this.missedDays,
    required this.completionRate,
    required this.currentStreak,
    required this.longestStreak,
    required this.totalDays,
    required this.daysPassed,
  });

  String get weekRange => 
      '${DateFormat('MMM d').format(weekStart)} - ${DateFormat('MMM d').format(weekEnd)}';
  
  String get completionPercentage => '${(completionRate * 100).toStringAsFixed(0)}%';
  
  bool get isPerfectWeek => trackedDays == daysPassed && daysPassed > 0;
  
  int get remainingDays => totalDays - trackedDays;
}
