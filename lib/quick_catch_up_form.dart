import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class QuickCatchUpForm extends StatefulWidget {
  final List<DateTime> missedDates;
  final Function(List<DateTime>) onComplete;
  final Function()? onCancel;

  const QuickCatchUpForm({
    super.key,
    required this.missedDates,
    required this.onComplete,
    this.onCancel,
  });

  @override
  State<QuickCatchUpForm> createState() => _QuickCatchUpFormState();
}

class _QuickCatchUpFormState extends State<QuickCatchUpForm> {
  final Map<DateTime, bool> _selectedDates = {};
  bool _isSubmitting = false;
  bool _selectAll = true;

  @override
  void initState() {
    super.initState();
    // Select all dates by default
    for (final date in widget.missedDates) {
      _selectedDates[date] = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = _selectedDates.values.where((v) => v).length;
    
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
const Icon(Icons.cached, color: Colors.blue, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Catch Up on Missed Days',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${widget.missedDates.length} missed day${widget.missedDates.length > 1 ? 's' : ''} found',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Select all toggle
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Checkbox(
                    value: _selectAll,
                    onChanged: (value) {
                      setState(() {
                        _selectAll = value ?? false;
                        for (final date in widget.missedDates) {
                          _selectedDates[date] = _selectAll;
                        }
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  const Text('Select All'),
                  const Spacer(),
                  Text(
                    '$selectedCount selected',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            
            // Divider
            Divider(color: Colors.grey.shade300, height: 1),
            
            // Dates list
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    children: widget.missedDates.map((date) => _buildDateItem(date)).toList(),
                  ),
                ),
              ),
            ),
            
            // Divider
            Divider(color: Colors.grey.shade300, height: 1),
            
            // Buttons
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSubmitting ? null : () {
                        Navigator.pop(context);
                        widget.onCancel?.call();
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSubmitting || selectedCount == 0
                          ? null
                          : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.check, size: 18),
                                const SizedBox(width: 8),
                                Text('Mark $selectedCount Day${selectedCount > 1 ? 's' : ''}'),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateItem(DateTime date) {
    final isSelected = _selectedDates[date] ?? false;
    final isToday = _isToday(date);
    final isYesterday = _isYesterday(date);
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedDates[date] = !isSelected;
            // Update select all if needed
            final allSelected = widget.missedDates.every((d) => _selectedDates[d] ?? false);
            if (_selectAll != allSelected) {
              _selectAll = allSelected;
            }
          });
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              Checkbox(
                value: isSelected,
                onChanged: (value) {
                  setState(() {
                    _selectedDates[date] = value ?? false;
                  });
                },
              ),
              const SizedBox(width: 12),
              // Date icon
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _getDateColor(date).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getDateIcon(date),
                  size: 18,
                  color: _getDateColor(date),
                ),
              ),
              const SizedBox(width: 12),
              // Date info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getDateTitle(date),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('EEEE, MMMM d, yyyy').format(date),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              // Status badge
              if (isToday || isYesterday)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isToday ? Colors.green.shade100 : Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    isToday ? 'Today' : 'Yesterday',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isToday ? Colors.green.shade800 : Colors.blue.shade800,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    
    try {
      final selectedDates = _selectedDates.entries
          .where((entry) => entry.value)
          .map((entry) => entry.key)
          .toList();
      
      await widget.onComplete(selectedDates);
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Successfully marked ${selectedDates.length} day${selectedDates.length > 1 ? 's' : ''}',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  // Helper methods
  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && 
           date.month == now.month && 
           date.day == now.day;
  }

  bool _isYesterday(DateTime date) {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return date.year == yesterday.year && 
           date.month == yesterday.month && 
           date.day == yesterday.day;
  }

  String _getDateTitle(DateTime date) {
    if (_isToday(date)) return 'Today';
    if (_isYesterday(date)) return 'Yesterday';
    
    final difference = DateTime.now().difference(date).inDays;
    if (difference == 2) return 'Day Before Yesterday';
    if (difference < 7) return '$difference Days Ago';
    
    return DateFormat('MMM d').format(date);
  }

  IconData _getDateIcon(DateTime date) {
    if (_isToday(date)) return Icons.today;
  if (_isYesterday(date)) return Icons.history; // <-- replaces nonexistent 'yesterday'
    return Icons.calendar_today;
  }

  Color _getDateColor(DateTime date) {
    if (_isToday(date)) return Colors.green;
    if (_isYesterday(date)) return Colors.blue;
    return Colors.orange;
  }
}
