// import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';
// import 'attendance_tracker.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'plan_adherence_tracker.dart';
// import 'analytics_dashboard.dart';
// import 'attendance_tracker.dart';


// class AttendanceAnalyticsWidget extends StatefulWidget {
//   final String userId;
//   final FirebaseFirestore firestore;
//   final VoidCallback? onRefresh;

//   const AttendanceAnalyticsWidget({
//     super.key,
//     required this.userId,
//     required this.firestore,
//     this.onRefresh,
//   });

//   @override
//   State<AttendanceAnalyticsWidget> createState() => _AttendanceAnalyticsWidgetState();
// }

// class _AttendanceAnalyticsWidgetState extends State<AttendanceAnalyticsWidget> {
//   late AttendanceTracker _tracker;
//   WeeklyAttendanceSummary? _weeklySummary;
//   bool _isLoading = true;

//   @override
//   void initState() {
//     super.initState();
//   _tracker = AttendanceTracker(userId: widget.userId, firestore: widget.firestore);
//     _loadWeeklySummary();
//   }

//   Future<void> _loadWeeklySummary() async {
//     if (!mounted) return;
    
//     setState(() => _isLoading = true);
//     try {
//       _weeklySummary = await _tracker.getWeeklySummary();
//     } catch (e) {
//       print('Error loading weekly summary: $e');
//     } finally {
//       if (mounted) {
//         setState(() => _isLoading = false);
//       }
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Card(
//       elevation: 2,
//       shape: RoundedRectangleBorder(
//         borderRadius: BorderRadius.circular(16),
//       ),
//       child: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             // Header
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 Row(
//                   children: [
//                     Icon(Icons.timeline, color: Theme.of(context).primaryColor),
//                     const SizedBox(width: 8),
//                     const Text(
//                       'Plan Adherence',
//                       style: TextStyle(
//                         fontSize: 16,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                   ],
//                 ),
//                 IconButton(
//                   icon: Icon(
//                     _isLoading ? Icons.refresh : Icons.refresh,
//                     color: _isLoading ? Colors.grey : Theme.of(context).primaryColor,
//                   ),
//                   onPressed: _isLoading ? null : _loadWeeklySummary,
//                 ),
//               ],
//             ),
            
//             const SizedBox(height: 16),
            
//             // Content
//             _isLoading
//                 ? _buildLoading()
//                 : _weeklySummary == null
//                     ? _buildEmptyState()
//                     : _buildSummaryContent(),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildLoading() {
//     return const Center(
//       child: Padding(
//         padding: EdgeInsets.symmetric(vertical: 40),
//         child: CircularProgressIndicator(),
//       ),
//     );
//   }

//   Widget _buildEmptyState() {
//     return Column(
//       children: [
//         const Icon(Icons.calendar_today, size: 48, color: Colors.grey),
//         const SizedBox(height: 12),
//         const Text(
//           'Start Tracking Your Progress',
//           style: TextStyle(fontWeight: FontWeight.bold),
//         ),
//         const SizedBox(height: 8),
//         Text(
//           'Complete your daily meals to track adherence',
//           style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
//           textAlign: TextAlign.center,
//         ),
//       ],
//     );
//   }

//   Widget _buildSummaryContent() {
//     final summary = _weeklySummary!;
    
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         // Week info
//         Row(
//           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//           children: [
//             Text(
//               'This Week',
//               style: TextStyle(
//                 fontSize: 14,
//                 fontWeight: FontWeight.w500,
//                 color: Colors.grey.shade700,
//               ),
//             ),
//             Text(
//               summary.weekRange,
//               style: TextStyle(
//                 fontSize: 12,
//                 color: Colors.grey.shade600,
//               ),
//             ),
//           ],
//         ),
        
//         const SizedBox(height: 16),
        
//         // Progress section
//         _buildProgressSection(summary),
//         const SizedBox(height: 20),
        
//         // Stats grid
//         _buildStatsGrid(summary),
//         const SizedBox(height: 16),
        
//         // Encouragement message
//         if (summary.daysPassed > 0) _buildEncouragementMessage(summary),
//       ],
//     );
//   }

//   Widget _buildProgressSection(WeeklyAttendanceSummary summary) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Row(
//           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//           children: [
//             Text(
//               '${summary.completionPercentage} Complete',
//               style: const TextStyle(
//                 fontSize: 14,
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
//             Text(
//               '${summary.trackedDays}/${summary.daysPassed} days',
//               style: TextStyle(
//                 fontSize: 12,
//                 color: Colors.grey.shade600,
//               ),
//             ),
//           ],
//         ),
        
//         const SizedBox(height: 8),
        
//         // Progress bar
//         Stack(
//           children: [
//             Container(
//               height: 10,
//               decoration: BoxDecoration(
//                 color: Colors.grey.shade200,
//                 borderRadius: BorderRadius.circular(5),
//               ),
//             ),
//             AnimatedContainer(
//               duration: const Duration(milliseconds: 500),
//               height: 10,
//               width: MediaQuery.of(context).size.width * 0.8 * summary.completionRate,
//               decoration: BoxDecoration(
//                 gradient: LinearGradient(
//                   colors: _getProgressColors(summary.completionRate),
//                 ),
//                 borderRadius: BorderRadius.circular(5),
//               ),
//             ),
//           ],
//         ),
        
//         const SizedBox(height: 4),
        
//         // Days indicator
//         if (summary.daysPassed > 0)
//           Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: List.generate(7, (index) {
//               final dayDate = summary.weekStart.add(Duration(days: index));
//               final isPast = dayDate.isBefore(DateTime.now()) || 
//                   dayDate.day == DateTime.now().day;
//               final isTracked = _isDayTracked(summary, dayDate);
              
//               return _buildDayIndicator(
//                 dayDate,
//                 isPast: isPast,
//                 isTracked: isTracked,
//               );
//             }),
//           ),
//       ],
//     );
//   }

//   Widget _buildDayIndicator(DateTime date, {required bool isPast, required bool isTracked}) {
//     final dayName = DateFormat('E').format(date)[0];
    
//     return Column(
//       children: [
//         Container(
//           width: 24,
//           height: 24,
//           decoration: BoxDecoration(
//             color: isPast
//                 ? (isTracked ? Colors.green : Colors.grey.shade300)
//                 : Colors.transparent,
//             shape: BoxShape.circle,
//             border: Border.all(
//               color: isPast ? Colors.transparent : Colors.grey.shade300,
//             ),
//           ),
//           child: Center(
//             child: Text(
//               dayName,
//               style: TextStyle(
//                 fontSize: 10,
//                 fontWeight: FontWeight.bold,
//                 color: isPast
//                     ? (isTracked ? Colors.white : Colors.grey.shade600)
//                     : Colors.grey.shade400,
//               ),
//             ),
//           ),
//         ),
//         const SizedBox(height: 2),
//         Text(
//           date.day.toString(),
//           style: TextStyle(
//             fontSize: 10,
//             color: isPast ? Colors.grey.shade700 : Colors.grey.shade400,
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _buildStatsGrid(WeeklyAttendanceSummary summary) {
//     return GridView.count(
//       shrinkWrap: true,
//       physics: const NeverScrollableScrollPhysics(),
//       crossAxisCount: 2,
//       childAspectRatio: 2.5,
//       mainAxisSpacing: 8,
//       crossAxisSpacing: 8,
//       children: [
//         _buildStatCard(
//           'Current Streak',
//           '${summary.currentStreak} days',
//           Icons.local_fire_department,
//           summary.currentStreak > 0 ? Colors.orange : Colors.grey,
//         ),
//         _buildStatCard(
//           'Longest Streak',
//           '${summary.longestStreak} days',
//           Icons.emoji_events,
//           Colors.blue,
//         ),
//         _buildStatCard(
//           'Tracked This Week',
//           '${summary.trackedDays}/${summary.daysPassed}',
//           Icons.check_circle,
//           Colors.green,
//         ),
//         _buildStatCard(
//           'Completion Rate',
//           summary.completionPercentage,
//           Icons.trending_up,
//           _getCompletionColor(summary.completionRate),
//         ),
//       ],
//     );
//   }

//   Widget _buildStatCard(String title, String value, IconData icon, Color color) {
//     return Container(
//       padding: const EdgeInsets.all(12),
//       decoration: BoxDecoration(
//         color: color.withOpacity(0.1),
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: color.withOpacity(0.2)),
//       ),
//       child: Row(
//         children: [
//           Container(
//             padding: const EdgeInsets.all(6),
//             decoration: BoxDecoration(
//               color: color.withOpacity(0.2),
//               shape: BoxShape.circle,
//             ),
//             child: Icon(icon, size: 18, color: color),
//           ),
//           const SizedBox(width: 12),
//           Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               Text(
//                 value,
//                 style: TextStyle(
//                   fontSize: 16,
//                   fontWeight: FontWeight.bold,
//                   color: color,
//                 ),
//               ),
//               Text(
//                 title,
//                 style: TextStyle(
//                   fontSize: 10,
//                   color: Colors.grey.shade600,
//                 ),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildEncouragementMessage(WeeklyAttendanceSummary summary) {
//     String message;
//     Color color;
//     IconData icon;
    
//     if (summary.isPerfectWeek) {
//       message = 'Perfect week! Keep up the amazing work! 🎉';
//       color = Colors.green;
//       icon = Icons.celebration;
//     } else if (summary.completionRate >= 0.8) {
//       message = 'Great job! You\'re consistently following your plan.';
//       color = Colors.blue;
//       icon = Icons.thumb_up;
//     } else if (summary.completionRate >= 0.5) {
//       message = 'Good progress! Try to complete a few more days this week.';
//       color = Colors.orange;
//       icon = Icons.trending_up;
//     } else if (summary.trackedDays > 0) {
//       message = 'Every day counts! You can do this! 💪';
//       color = Colors.orange;
//       icon = Icons.lightbulb;
//     } else {
//       message = 'Start tracking today to build your streak!';
//       color = Colors.grey;
//       icon = Icons.calendar_today;
//     }
    
//     return Container(
//       padding: const EdgeInsets.all(12),
//       decoration: BoxDecoration(
//         color: color.withOpacity(0.1),
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: color.withOpacity(0.2)),
//       ),
//       child: Row(
//         children: [
//           Icon(icon, color: color),
//           const SizedBox(width: 12),
//           Expanded(
//             child: Text(
//               message,
//               style: TextStyle(
//                 fontSize: 12,
//                 color: color,
//                 fontWeight: FontWeight.w500,
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   // Helper methods
//   bool _isDayTracked(WeeklyAttendanceSummary summary, DateTime day) {
//     final dayStr = DateFormat('yyyy-MM-dd').format(day);
//     // This is a simplified check - in real implementation, 
//     // you'd check against actual tracked days
//     return day.isBefore(DateTime.now()) && 
//            day.weekday <= DateTime.now().weekday &&
//            summary.trackedDays > day.weekday - 1;
//   }

//   List<Color> _getProgressColors(double rate) {
//     if (rate >= 0.9) return [Colors.green, Colors.lightGreen];
//     if (rate >= 0.7) return [Colors.blue, Colors.lightBlue];
//     if (rate >= 0.5) return [Colors.orange, Colors.amber];
//     return [Colors.red, Colors.orange];
//   }

//   Color _getCompletionColor(double rate) {
//     if (rate >= 0.9) return Colors.green;
//     if (rate >= 0.7) return Colors.blue;
//     if (rate >= 0.5) return Colors.orange;
//     return Colors.red;
//   }
// }
