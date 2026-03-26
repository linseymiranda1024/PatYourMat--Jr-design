import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../main.dart';
import '../../models/gym_class.dart';

class ScreenCreateClass extends ConsumerStatefulWidget {
  static const routeName = '/staff/create-class';
  final GymClass? existingClass;

  const ScreenCreateClass({super.key, this.existingClass});

  @override
  ConsumerState<ScreenCreateClass> createState() => _ScreenCreateClassState();
}

class _ScreenCreateClassState extends ConsumerState<ScreenCreateClass> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _instructorController = TextEditingController();
  final _locationController = TextEditingController();
  final _capacityController = TextEditingController();
  final _durationController = TextEditingController(text: '60');

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  String _selectedType = gymClassTypes.first;
  bool _isSubmitting = false;
  bool get _isEditing => widget.existingClass != null;

  DateTime get _selectedDateTime => DateTime(
    _selectedDate.year,
    _selectedDate.month,
    _selectedDate.day,
    _selectedTime.hour,
    _selectedTime.minute,
  );

  DateTime get _selectedEndDateTime {
    final duration = int.tryParse(_durationController.text.trim()) ?? 60;
    return _selectedDateTime.add(Duration(minutes: duration.clamp(1, 1440)));
  }

  @override
  void initState() {
    super.initState();
    final existingClass = widget.existingClass;
    if (existingClass == null) {
      return;
    }

    _titleController.text = existingClass.title;
    _descriptionController.text = existingClass.description;
    _instructorController.text = existingClass.instructor;
    _locationController.text = existingClass.location;
    _capacityController.text = existingClass.capacity.toString();
    _durationController.text = existingClass.durationMinutes.toString();
    final normalizedType = normalizeGymClassType(existingClass.type);
    _selectedType = gymClassTypes.contains(normalizedType)
        ? normalizedType
        : gymClassTypes.first;
    _selectedDate = existingClass.dateTime;
    _selectedTime = TimeOfDay.fromDateTime(existingClass.dateTime);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _instructorController.dispose();
    _locationController.dispose();
    _capacityController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final today = DateTime.now();
    final firstDate = _isEditing && _selectedDate.isBefore(today)
        ? DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day)
        : DateTime(today.year, today.month, today.day);
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: firstDate,
      lastDate: today.add(const Duration(days: 365)),
    );
    if (date != null) setState(() => _selectedDate = date);
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (time != null) setState(() => _selectedTime = time);
  }

  bool _isScheduleSelectionValid() {
    final selectedDateTime = _selectedDateTime;
    final now = DateTime.now();

    if (!selectedDateTime.isBefore(now)) {
      return true;
    }

    final existingClass = widget.existingClass;
    if (existingClass == null) {
      return false;
    }

    final existingDateTime = existingClass.dateTime;
    return existingDateTime.year == selectedDateTime.year &&
        existingDateTime.month == selectedDateTime.month &&
        existingDateTime.day == selectedDateTime.day &&
        existingDateTime.hour == selectedDateTime.hour &&
        existingDateTime.minute == selectedDateTime.minute;
  }

  String? _validatePositiveNumber(
    String? value, {
    required String emptyMessage,
    required String invalidMessage,
    required int minValue,
  }) {
    if (value == null || value.trim().isEmpty) {
      return emptyMessage;
    }

    final parsed = int.tryParse(value.trim());
    if (parsed == null || parsed < minValue) {
      return invalidMessage;
    }
    return null;
  }

  Future<void> _submitClass() async {
    if (_isSubmitting) return;
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;
    if (!_isScheduleSelectionValid()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please choose a date and time that is not in the past.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final existingClass = widget.existingClass;
    final capacity = int.tryParse(_capacityController.text.trim()) ?? 20;
    final filled = existingClass == null
        ? 0
        : existingClass.filled.clamp(0, capacity);
    final status = filled >= capacity
        ? ClassStatus.full
        : (existingClass?.status == ClassStatus.standby
              ? ClassStatus.standby
              : ClassStatus.open);

    final classToSave = GymClass(
      id: existingClass?.id ?? '',
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      type: _selectedType,
      instructor: _instructorController.text.trim(),
      dateTime: _selectedDateTime,
      durationMinutes: int.tryParse(_durationController.text.trim()) ?? 60,
      location: _locationController.text.trim(),
      capacity: capacity,
      filled: filled,
      status: status,
    );

    try {
      if (_isEditing) {
        await ref.read(providerGymClass).updateClass(classToSave);
      } else {
        await ref.read(providerGymClass).addClass(classToSave);
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final selectedDateTime = _selectedDateTime;
    final endDateTime = _selectedEndDateTime;
    final isScheduleValid = _isScheduleSelectionValid();

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Class' : 'Create New Class'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Class Details',
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Set the basics for how this class will appear across the app.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Class Title',
                    prefixIcon: Icon(Icons.title_rounded),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Please enter a title'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    alignLabelWithHint: true,
                    prefixIcon: Padding(
                      padding: EdgeInsets.only(bottom: 64),
                      child: Icon(Icons.subject_rounded),
                    ),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Please enter a description'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _instructorController,
                  decoration: const InputDecoration(
                    labelText: 'Instructor',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Please enter an instructor'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _locationController,
                  decoration: const InputDecoration(
                    labelText: 'Location',
                    prefixIcon: Icon(Icons.location_on_outlined),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Please enter a location'
                      : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _selectedType,
                  decoration: const InputDecoration(
                    labelText: 'Type',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: gymClassTypes
                      .map(
                        (type) => DropdownMenuItem<String>(
                          value: type,
                          child: Text(type),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _selectedType = value);
                  },
                  validator: (value) => value == null || value.isEmpty
                      ? 'Please select a class type'
                      : null,
                ),
                const SizedBox(height: 24),
                Divider(color: colorScheme.outlineVariant),
                const SizedBox(height: 20),
                Text(
                  'Scheduling',
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose when the class happens and how many spots are available.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _capacityController,
                        decoration: const InputDecoration(
                          labelText: 'Capacity',
                          prefixIcon: Icon(Icons.group_outlined),
                        ),
                        onChanged: (_) => setState(() {}),
                        keyboardType: TextInputType.number,
                        validator: (value) => _validatePositiveNumber(
                          value,
                          emptyMessage: 'Enter capacity',
                          invalidMessage: 'Capacity must be at least 1',
                          minValue: 1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _durationController,
                        decoration: const InputDecoration(
                          labelText: 'Duration (min)',
                          prefixIcon: Icon(Icons.timer_outlined),
                        ),
                        onChanged: (_) => setState(() {}),
                        keyboardType: TextInputType.number,
                        validator: (value) => _validatePositiveNumber(
                          value,
                          emptyMessage: 'Enter duration',
                          invalidMessage: 'Duration must be at least 15 min',
                          minValue: 15,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: _SchedulePickerCard(
                        label: 'Date',
                        value: DateFormat.yMMMMd().format(_selectedDate),
                        icon: Icons.calendar_today,
                        onTap: _pickDate,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SchedulePickerCard(
                        label: 'Time',
                        value: _selectedTime.format(context),
                        icon: Icons.access_time,
                        onTap: _pickTime,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isScheduleValid
                          ? colorScheme.outlineVariant
                          : colorScheme.error.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        isScheduleValid
                            ? Icons.schedule_rounded
                            : Icons.warning_amber_rounded,
                        color: isScheduleValid
                            ? colorScheme.primary
                            : colorScheme.error,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Schedule Preview',
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${DateFormat.yMMMMEEEEd().add_jm().format(selectedDateTime)} to ${DateFormat.jm().format(endDateTime)}',
                              style: textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurface,
                                fontWeight: FontWeight.w600,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$_selectedType • ${_capacityController.text.trim().isEmpty ? 'Capacity TBD' : '${_capacityController.text.trim()} mats'} • ${_durationController.text.trim().isEmpty ? 'Duration TBD' : '${_durationController.text.trim()} min'}',
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                height: 1.4,
                              ),
                            ),
                            if (!isScheduleValid) ...[
                              const SizedBox(height: 8),
                              Text(
                                'This class is scheduled in the past. Choose a future time to save it.',
                                style: textTheme.bodySmall?.copyWith(
                                  color: colorScheme.error,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitClass,
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_isEditing ? 'Save Changes' : 'Create Class'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SchedulePickerCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  const _SchedulePickerCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: colorScheme.primary),
            const SizedBox(height: 12),
            Text(
              label,
              style: textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
