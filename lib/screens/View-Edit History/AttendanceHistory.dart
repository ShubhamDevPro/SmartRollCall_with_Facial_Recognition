// File: AttendanceHistory.dart
// Purpose: Displays and manages attendance history for a batch of students
// Features: Date selection, search, attendance status updates, and Excel export

import 'package:flutter/material.dart';
import 'package:smart_roll_call_flutter/services/firestore_service.dart';
import 'package:smart_roll_call_flutter/screens/View-Edit History/attendance_history_card.dart';
import 'package:smart_roll_call_flutter/screens/View-Edit History/attendance_summary_card.dart';
import 'package:smart_roll_call_flutter/screens/View-Edit History/excel_export.dart';

/// Screen widget that displays attendance history for a specific batch
/// Allows viewing and editing attendance records for different dates
class AttendanceHistoryScreen extends StatefulWidget {
  // Unique identifier for the batch whose attendance is being displayed
  final String? batchId;

  const AttendanceHistoryScreen({super.key, this.batchId});

  @override
  _AttendanceHistoryScreenState createState() =>
      _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  // Service instance to interact with Firestore database
  final FirestoreService _firestoreService = FirestoreService();
  // Controller for the search text field
  final TextEditingController _searchController = TextEditingController();

  // Currently selected date for attendance viewing
  DateTime selectedDate = DateTime.now();
  // List to store all attendance records
  List<Map<String, dynamic>> attendanceData = [];
  // List to store filtered attendance records based on search
  List<Map<String, dynamic>> filteredAttendanceData = [];
  // NEW: Grouped attendance data by schedule
  Map<String, List<Map<String, dynamic>>> groupedAttendanceData = {};
  // Loading state flag
  bool isLoading = false;
  // NEW: Cache for schedule information
  Map<String, String> scheduleCache = {};

  @override
  void initState() {
    super.initState();
    // Load attendance data when screen initializes
    _loadAttendanceData();
  }

  @override
  void dispose() {
    // Clean up the controller when the widget is disposed
    _searchController.dispose();
    super.dispose();
  }

  /// Filters the attendance list based on search query
  /// Matches student name or enrollment number
  void _filterAttendance(String query) {
    setState(() {
      if (query.isEmpty) {
        // If search is empty, show all records
        filteredAttendanceData = attendanceData;
        _groupAttendanceBySchedule();
      } else {
        // Filter based on name or enrollment number
        filteredAttendanceData = attendanceData.where((student) {
          final nameLower = student['name'].toString().toLowerCase();
          final enrollLower = student['enrollNumber'].toString().toLowerCase();
          final searchLower = query.toLowerCase();
          return nameLower.contains(searchLower) ||
              enrollLower.contains(searchLower);
        }).toList();
        _groupAttendanceBySchedule();
      }
    });
  }

  /// Groups attendance data by schedule ID for better organization
  void _groupAttendanceBySchedule() {
    groupedAttendanceData.clear();

    for (var record in filteredAttendanceData) {
      final scheduleId = record['scheduleId'] as String? ?? 'unknown';

      if (!groupedAttendanceData.containsKey(scheduleId)) {
        groupedAttendanceData[scheduleId] = [];
      }
      groupedAttendanceData[scheduleId]!.add(record);
    }
  }

  /// Fetches attendance data from Firestore for the selected date
  Future<void> _loadAttendanceData() async {
    try {
      // Check if widget is still mounted before calling setState
      if (!mounted) return;

      setState(() {
        isLoading = true;
      });

      // Get attendance records for all students on selected date
      final data = await _firestoreService.getAttendanceForDateAll(
        selectedDate,
        widget.batchId,
      );

      // NEW: Load schedule information for display
      if (widget.batchId != null) {
        final schedules =
            await _firestoreService.getCourseSchedulesList(widget.batchId!);
        scheduleCache = Map.fromEntries(schedules
            .map((schedule) => MapEntry(schedule.id, schedule.displayString)));
      }

      setState(() {
        attendanceData = data;
        filteredAttendanceData = data;
        _groupAttendanceBySchedule();
      });

      if (!mounted) return; // Check again before final setState
      setState(() {
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      // Show error message if data loading fails
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading attendance: $e')),
      );
      setState(() {
        isLoading = false;
      });
    }
  }

  /// Updates attendance status for a student
  /// Toggles between present and absent
  Future<void> _updateAttendanceStatus(Map<String, dynamic> student) async {
    setState(() => isLoading = true);

    try {
      // Toggle the attendance status
      final newStatus = !student['isPresent'];
      final attendanceRecordId = student['attendanceRecordId'] as String?;

      if (attendanceRecordId != null) {
        // NEW: Use new method that updates attendance_records collection
        await _firestoreService.updateAttendanceRecord(
          attendanceRecordId,
          newStatus,
        );
      } else {
        // Fallback to old method for backward compatibility
        await _firestoreService.updateAttendanceStatus(
          student['batchId'],
          student['enrollNumber'],
          selectedDate,
          newStatus,
        );
      }

      // Reload data to reflect changes
      await _loadAttendanceData();

      if (!mounted) return;
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Attendance updated successfully'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      // Show error message if update fails
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating attendance: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  /// Exports attendance data to Excel file
  Future<void> _exportAttendanceData() async {
    setState(() => isLoading = true);
    try {
      final data =
          await _firestoreService.getAttendanceHistory(widget.batchId!);
      await ExcelExportUtil.exportAttendanceData(
        data: data,
        selectedDate: selectedDate,
        onError: (error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error exporting data: $error'),
              backgroundColor: Colors.red,
            ),
          );
        },
        onSuccess: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Attendance data exported successfully'),
            ),
          );
        },
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  /// Builds a simple list view when there's only one schedule for the day
  Widget _buildSingleScheduleView() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredAttendanceData.length,
      itemBuilder: (context, index) {
        final student = filteredAttendanceData[index];
        final scheduleId = student['scheduleId'] as String?;
        final scheduleInfo =
            scheduleId != null ? scheduleCache[scheduleId] : null;

        return AttendanceHistoryCard(
          name: student['name'],
          enrollNumber: student['enrollNumber'],
          isPresent: student['isPresent'],
          onStatusChanged: () => _updateAttendanceStatus(student),
          totalDays: student['totalDays'] ?? 0,
          presentDays: student['presentDays'] ?? 0,
          scheduleInfo: scheduleInfo,
        );
      },
    );
  }

  /// Builds an organized view when there are multiple schedules for the day
  Widget _buildMultipleScheduleView() {
    // Sort schedules by start time
    final sortedScheduleIds = groupedAttendanceData.keys.toList()
      ..sort((a, b) {
        final scheduleA = scheduleCache[a] ?? '';
        final scheduleB = scheduleCache[b] ?? '';
        return scheduleA.compareTo(scheduleB);
      });

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedScheduleIds.length,
      itemBuilder: (context, scheduleIndex) {
        final scheduleId = sortedScheduleIds[scheduleIndex];
        final scheduleRecords = groupedAttendanceData[scheduleId] ?? [];
        final scheduleInfo = scheduleCache[scheduleId] ?? 'Unknown Schedule';

        // Calculate statistics for this schedule
        final present =
            scheduleRecords.where((r) => r['isPresent'] == true).length;
        final total = scheduleRecords.length;

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Schedule header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.schedule,
                      color: Theme.of(context).primaryColor,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        scheduleInfo,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.green.withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        '$present/$total Present',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.green,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Student list for this schedule
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.all(8),
                itemCount: scheduleRecords.length,
                itemBuilder: (context, studentIndex) {
                  final student = scheduleRecords[studentIndex];

                  return AttendanceHistoryCard(
                    name: student['name'],
                    enrollNumber: student['enrollNumber'],
                    isPresent: student['isPresent'],
                    onStatusChanged: () => _updateAttendanceStatus(student),
                    totalDays: student['totalDays'] ?? 0,
                    presentDays: student['presentDays'] ?? 0,
                    scheduleInfo:
                        null, // Don't show schedule info in card since it's in header
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance History'),
        actions: [
          // Export button in app bar
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _exportAttendanceData,
            tooltip: 'Export Attendance Data',
          ),
        ],
      ),
      body: Column(
        children: [
          // Date selection and search section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                // Date navigation row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Previous day button
                    IconButton(
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(),
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () {
                        setState(() {
                          selectedDate =
                              selectedDate.subtract(const Duration(days: 1));
                          _loadAttendanceData();
                        });
                      },
                    ),
                    // Date picker button
                    Flexible(
                      child: TextButton(
                        onPressed: () async {
                          final DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null && picked != selectedDate) {
                            setState(() {
                              selectedDate = picked;
                              _loadAttendanceData();
                            });
                          }
                        },
                        child: Text(
                          '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                          style: const TextStyle(fontSize: 16),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    // Next day button (disabled if date is today)
                    IconButton(
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(),
                      icon: const Icon(Icons.chevron_right),
                      onPressed: selectedDate.isBefore(DateTime.now())
                          ? () {
                              setState(() {
                                selectedDate =
                                    selectedDate.add(const Duration(days: 1));
                                _loadAttendanceData();
                              });
                            }
                          : null,
                    ),
                  ],
                ),
                // Search field
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search by name or enrollment number',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                _filterAttendance('');
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    onChanged: _filterAttendance,
                  ),
                ),
              ],
            ),
          ),

          // Attendance summary cards section
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // Total students card
                Expanded(
                  child: AttendanceSummaryCard(
                    title: 'Total',
                    count: filteredAttendanceData.length.toString(),
                    icon: Icons.people,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 8), // Add spacing between cards
                // Present students card
                Expanded(
                  child: AttendanceSummaryCard(
                    title: 'Present',
                    count: filteredAttendanceData
                        .where((s) => s['isPresent'])
                        .length
                        .toString(),
                    icon: Icons.check_circle,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 8), // Add spacing between cards
                // Absent students card
                Expanded(
                  child: AttendanceSummaryCard(
                    title: 'Absent',
                    count: filteredAttendanceData
                        .where((s) => !s['isPresent'])
                        .length
                        .toString(),
                    icon: Icons.cancel,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
          ),

          // Attendance list section
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredAttendanceData.isEmpty
                    ? Center(
                        child: Text(
                          _searchController.text.isEmpty
                              ? 'No attendance records for this date'
                              : 'No students found',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      )
                    : groupedAttendanceData.length == 1
                        ? _buildSingleScheduleView()
                        : _buildMultipleScheduleView(),
          ),
        ],
      ),
    );
  }
}
