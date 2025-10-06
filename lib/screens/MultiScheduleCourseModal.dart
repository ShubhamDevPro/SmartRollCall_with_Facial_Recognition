import 'package:flutter/material.dart';
import 'package:smart_roll_call_flutter/widgets/batches.dart';
import 'package:smart_roll_call_flutter/models/batch_schedule.dart';

class MultiScheduleCourseModal extends StatefulWidget {
  final Function(String title, String batchName, String batchYear, IconData iconData, List<Map<String, String>> schedules) onSave;

  // Optional initial values for editing
  final String? initialTitle;
  final String? initialBatchName;
  final String? initialBatchYear;
  final IconData? initialIcon;
  final List<Map<String, String>>? initialSchedules;

  const MultiScheduleCourseModal({
    super.key,
    required this.onSave,
    this.initialTitle,
    this.initialBatchName,
    this.initialBatchYear,
    this.initialIcon,
    this.initialSchedules,
  });

  @override
  State<MultiScheduleCourseModal> createState() => _MultiScheduleCourseModalState();
}

class _MultiScheduleCourseModalState extends State<MultiScheduleCourseModal> {
  late final titleController = TextEditingController(text: widget.initialTitle);
  late final batchNameController = TextEditingController(text: widget.initialBatchName);
  late final batchYearController = TextEditingController(text: widget.initialBatchYear);

  late String selectedCourseType = _getCourseTypeFromIcon(widget.initialIcon);
  bool _isLoading = false;

  // List to store multiple schedules
  List<Map<String, String>> schedules = [];

  // List to store controllers for each schedule's time fields
  List<Map<String, TextEditingController>> scheduleControllers = [];

  final List<String> _daysOfWeek = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
  ];

  @override
  void initState() {
    super.initState();
    // Initialize with existing schedules or add one default schedule
    if (widget.initialSchedules != null && widget.initialSchedules!.isNotEmpty) {
      schedules = List.from(widget.initialSchedules!);
    } else {
      schedules = [
        {
          'dayOfWeek': 'Monday',
          'startTime': '09:00',
          'endTime': '10:00',
        }
      ];
    }

    // Initialize controllers for each schedule
    _initializeScheduleControllers();
  }

  void _initializeScheduleControllers() {
    scheduleControllers.clear();
    for (var schedule in schedules) {
      scheduleControllers.add({
        'startTime': TextEditingController(text: schedule['startTime']),
        'endTime': TextEditingController(text: schedule['endTime']),
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        top: 16,
        left: 16,
        right: 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Text(
                  widget.initialTitle == null ? 'Add New Course' : 'Edit Course',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Course type selector
            Row(
              children: [
                CircleAvatar(
                  radius: 25,
                  child: Icon(
                    selectedCourseType == 'Practical' ? Icons.build : Icons.book,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 16),
                TextButton.icon(
                  onPressed: () => _showCourseTypePicker(context),
                  icon: const Icon(Icons.edit),
                  label: const Text('Change Course Type'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Course details form
            BatchFormFields(
              titleController: titleController,
              batchNameController: batchNameController,
              batchYearController: batchYearController,
            ),
            const SizedBox(height: 24),

            // Multiple Schedules Section
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Class Schedules',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        IconButton.outlined(
                          onPressed: _addNewSchedule,
                          icon: const Icon(Icons.add),
                          tooltip: 'Add Schedule',
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // List of schedules
                    ...schedules.asMap().entries.map((entry) {
                      final index = entry.key;
                      final schedule = entry.value;
                      return _buildScheduleItem(index, schedule);
                    }).toList(),

                    if (schedules.isEmpty)
                      Center(
                        child: Column(
                          children: [
                            const SizedBox(height: 20),
                            Icon(Icons.schedule, size: 48, color: Colors.grey[400]),
                            const SizedBox(height: 12),
                            Text(
                              'No schedules added',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 12),
                            TextButton.icon(
                              onPressed: _addNewSchedule,
                              icon: const Icon(Icons.add),
                              label: const Text('Add First Schedule'),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Save button
            ElevatedButton(
              onPressed: _isLoading ? null : _validateAndSave,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      widget.initialTitle == null ? 'Create Course' : 'Update Course',
                      style: const TextStyle(fontSize: 16),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleItem(int index, Map<String, String> schedule) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.schedule, size: 20, color: Colors.blue[700]),
                const SizedBox(width: 8),
                Text(
                  'Schedule ${index + 1}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                if (schedules.length > 1)
                  IconButton(
                    onPressed: () => _removeSchedule(index),
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Day of week dropdown
            DropdownButtonFormField<String>(
              value: schedule['dayOfWeek'],
              decoration: InputDecoration(
                labelText: 'Day of Week',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                prefixIcon: const Icon(Icons.calendar_today, size: 20),
              ),
              items: _daysOfWeek.map((day) => DropdownMenuItem(
                value: day,
                child: Text(day),
              )).toList(),
              onChanged: (value) => _updateSchedule(index, 'dayOfWeek', value!),
            ),
            const SizedBox(height: 12),

            // Time inputs row
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: scheduleControllers[index]['startTime'],
                    decoration: InputDecoration(
                      labelText: 'Start Time',
                      hintText: '09:00',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      prefixIcon: const Icon(Icons.access_time, size: 20),
                    ),
                    onTap: () => _selectTime(context, index, 'startTime'),
                    readOnly: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: scheduleControllers[index]['endTime'],
                    decoration: InputDecoration(
                      labelText: 'End Time',
                      hintText: '10:00',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      prefixIcon: const Icon(Icons.access_time_filled, size: 20),
                    ),
                    onTap: () => _selectTime(context, index, 'endTime'),
                    readOnly: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _addNewSchedule() {
    setState(() {
      schedules.add({
        'dayOfWeek': 'Monday',
        'startTime': '09:00',
        'endTime': '10:00',
      });
      // Add controllers for the new schedule
      scheduleControllers.add({
        'startTime': TextEditingController(text: '09:00'),
        'endTime': TextEditingController(text: '10:00'),
      });
    });
  }

  void _removeSchedule(int index) {
    setState(() {
      // Dispose controllers before removing
      scheduleControllers[index]['startTime']?.dispose();
      scheduleControllers[index]['endTime']?.dispose();

      schedules.removeAt(index);
      scheduleControllers.removeAt(index);
    });
  }

  void _updateSchedule(int index, String field, String value) {
    setState(() {
      schedules[index][field] = value;

      // Update controllers if it's a time field
      if (field == 'startTime') {
        scheduleControllers[index]['startTime']?.text = value;
      } else if (field == 'endTime') {
        scheduleControllers[index]['endTime']?.text = value;
      }
    });
  }

  Future<void> _selectTime(BuildContext context, int scheduleIndex, String timeType) async {
    final currentTime = schedules[scheduleIndex][timeType] ?? '09:00';
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _parseTimeString(currentTime),
    );

    if (picked != null) {
      final timeString = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      _updateSchedule(scheduleIndex, timeType, timeString);
    }
  }

  TimeOfDay _parseTimeString(String timeStr) {
    try {
      final parts = timeStr.split(':');
      return TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      );
    } catch (e) {
      return const TimeOfDay(hour: 9, minute: 0);
    }
  }

  void _validateAndSave() async {
    // Validation
    if (titleController.text.isEmpty ||
        batchNameController.text.isEmpty ||
        batchYearController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all course fields')),
      );
      return;
    }

    if (schedules.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one class schedule')),
      );
      return;
    }

    // Validate all schedules
    for (int i = 0; i < schedules.length; i++) {
      final schedule = schedules[i];
      if (!BatchSchedule.isValidTimeFormat(schedule['startTime']!) ||
          !BatchSchedule.isValidTimeFormat(schedule['endTime']!)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invalid time format in schedule ${i + 1}')),
        );
        return;
      }

      if (!BatchSchedule.isValidTimeRange(schedule['startTime']!, schedule['endTime']!)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invalid time range in schedule ${i + 1}')),
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      await widget.onSave(
        titleController.text,
        batchNameController.text,
        batchYearController.text,
        _getIconData(),
        schedules,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showCourseTypePicker(BuildContext context) {
    final List<String> courseTypes = ['Theory', 'Practical'];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Course Type'),
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
        content: SizedBox(
          height: 100,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: courseTypes.map((type) => _buildCourseTypeOption(type)).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildCourseTypeOption(String type) {
    final isSelected = selectedCourseType == type;
    return ListTile(
      leading: Icon(
        type == 'Practical' ? Icons.build : Icons.book,
        color: isSelected ? Theme.of(context).primaryColor : null,
      ),
      title: Text(
        type,
        style: TextStyle(
          color: isSelected ? Theme.of(context).primaryColor : null,
        ),
      ),
      dense: true,
      onTap: () {
        setState(() => selectedCourseType = type);
        Navigator.pop(context);
      },
    );
  }

  String _getCourseTypeFromIcon(IconData? icon) {
    return icon == Icons.build ? 'Practical' : 'Theory';
  }

  IconData _getIconData() {
    return selectedCourseType == 'Practical' ? Icons.build : Icons.book;
  }

  @override
  void dispose() {
    titleController.dispose();
    batchNameController.dispose();
    batchYearController.dispose();

    // Dispose all schedule controllers
    for (var controllers in scheduleControllers) {
      controllers['startTime']?.dispose();
      controllers['endTime']?.dispose();
    }

    super.dispose();
  }
}
