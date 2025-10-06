import 'package:flutter/material.dart';
import 'package:smart_roll_call_flutter/widgets/batches.dart';
import 'package:smart_roll_call_flutter/models/batch_schedule.dart';

// A modal widget that handles both creating and editing course information
class CourseModal extends StatefulWidget {
  // Callback function that will be called when saving the course
  // Takes course details as parameters and handles the save operation
  final Function(
          String title, String batchName, String batchYear, IconData iconData,
          String dayOfWeek, String startTime, String endTime)
      onSave;

  // Optional initial values for editing an existing course
  final String? initialTitle;
  final String? initialBatchName;
  final String? initialBatchYear;
  final IconData? initialIcon;
  final String? initialDayOfWeek;
  final String? initialStartTime;
  final String? initialEndTime;

  const CourseModal({
    super.key,
    required this.onSave,
    this.initialTitle,
    this.initialBatchName,
    this.initialBatchYear,
    this.initialIcon,
    this.initialDayOfWeek,
    this.initialStartTime,
    this.initialEndTime,
  });

  @override
  State<CourseModal> createState() => _CourseModalState();
}

class _CourseModalState extends State<CourseModal> {
  // Text controllers initialized with initial values if editing, or empty if creating new
  late final titleController = TextEditingController(text: widget.initialTitle);
  late final batchNameController =
      TextEditingController(text: widget.initialBatchName);
  late final batchYearController =
      TextEditingController(text: widget.initialBatchYear);
  late final startTimeController = 
      TextEditingController(text: widget.initialStartTime ?? '09:00');
  late final endTimeController = 
      TextEditingController(text: widget.initialEndTime ?? '10:00');

  // Tracks whether the course is Theory or Practical based on the icon
  late String selectedCourseType = _getCourseTypeFromIcon(widget.initialIcon);
  late String selectedDayOfWeek = widget.initialDayOfWeek ?? 'Monday';
  bool _isLoading = false;

  final List<String> _daysOfWeek = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
  ];

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
            Row(
              children: [
                Text(
                  widget.initialTitle == null
                      ? 'Add New Course'
                      : 'Edit Course',
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
            // Form fields
            BatchFormFields(
              titleController: titleController,
              batchNameController: batchNameController,
              batchYearController: batchYearController,
            ),
            const SizedBox(height: 16),
            
            // Scheduling section
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Class Schedule',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Day of week dropdown
                    DropdownButtonFormField<String>(
                      value: selectedDayOfWeek,
                      decoration: InputDecoration(
                        labelText: 'Day of Week',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.calendar_today),
                      ),
                      items: _daysOfWeek.map((day) => DropdownMenuItem(
                        value: day,
                        child: Text(day),
                      )).toList(),
                      onChanged: (value) => setState(() => selectedDayOfWeek = value!),
                    ),
                    const SizedBox(height: 16),
                    
                    // Time inputs row
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: startTimeController,
                            decoration: InputDecoration(
                              labelText: 'Start Time',
                              hintText: '09:00',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              prefixIcon: const Icon(Icons.access_time),
                            ),
                            validator: (value) => _validateTime(value),
                            onTap: () => _selectTime(context, startTimeController),
                            readOnly: true,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: endTimeController,
                            decoration: InputDecoration(
                              labelText: 'End Time',
                              hintText: '10:00',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              prefixIcon: const Icon(Icons.access_time_filled),
                            ),
                            validator: (value) => _validateTime(value),
                            onTap: () => _selectTime(context, endTimeController),
                            readOnly: true,
                          ),
                        ),
                      ],
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

  // Validates form inputs and calls the onSave callback
  void _validateAndSave() async {
    // Basic validation
    if (titleController.text.isEmpty ||
        batchNameController.text.isEmpty ||
        batchYearController.text.isEmpty ||
        startTimeController.text.isEmpty ||
        endTimeController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    // Validate time format and range
    if (!BatchSchedule.isValidTimeFormat(startTimeController.text) ||
        !BatchSchedule.isValidTimeFormat(endTimeController.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid time format (HH:MM)')),
      );
      return;
    }

    if (!BatchSchedule.isValidTimeRange(startTimeController.text, endTimeController.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Start time must be before end time')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Call the onSave callback with the current values including schedule
      await widget.onSave(
        titleController.text,
        batchNameController.text,
        batchYearController.text,
        _getIconData(),
        selectedDayOfWeek,
        startTimeController.text,
        endTimeController.text,
      );
      
      // Don't close the modal here - let the parent handle it
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

  // Time validation method
  String? _validateTime(String? value) {
    if (value == null || value.isEmpty) return 'Time is required';
    
    if (!BatchSchedule.isValidTimeFormat(value)) {
      return 'Enter valid time (HH:MM)';
    }
    
    return null;
  }

  // Time picker method
  Future<void> _selectTime(BuildContext context, TextEditingController controller) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _parseTimeString(controller.text),
    );
    
    if (picked != null) {
      setState(() {
        controller.text = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      });
    }
  }

  // Helper to parse time string to TimeOfDay
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

  // Shows a dialog to select course type (Theory/Practical)
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
            children: courseTypes
                .map((type) => _buildCourseTypeOption(type))
                .toList(),
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

  // Helper method to convert icon to course type string
  String _getCourseTypeFromIcon(IconData? icon) {
    return icon == Icons.build ? 'Practical' : 'Theory';
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
      dense: true, // Makes the ListTile more compact
      onTap: () {
        setState(() => selectedCourseType = type);
        Navigator.pop(context);
      },
    );
  }

  // Add this method to get the appropriate IconData
  IconData _getIconData() {
    return selectedCourseType == 'Practical' ? Icons.build : Icons.book;
  }

  @override
  void dispose() {
    titleController.dispose();
    batchNameController.dispose();
    batchYearController.dispose();
    startTimeController.dispose();
    endTimeController.dispose();
    super.dispose();
  }
}
