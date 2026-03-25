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
  bool _isSubmitting = false;
  bool get _isEditing => widget.existingClass != null;

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

  Future<void> _submitClass() async {
    if (_isSubmitting) return;
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;

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
      instructor: _instructorController.text.trim(),
      dateTime: DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      ),
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
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'Class Title'),
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
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Please enter a description'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _instructorController,
                  decoration: const InputDecoration(labelText: 'Instructor'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Please enter an instructor'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _locationController,
                  decoration: const InputDecoration(labelText: 'Location'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Please enter a location'
                      : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _capacityController,
                        decoration: const InputDecoration(
                          labelText: 'Capacity',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Enter capacity';
                          }
                          if (int.tryParse(value.trim()) == null) {
                            return 'Valid number';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _durationController,
                        decoration: const InputDecoration(
                          labelText: 'Duration (min)',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Enter duration';
                          }
                          if (int.tryParse(value.trim()) == null) {
                            return 'Valid number';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        const Text(
                          'Date',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextButton.icon(
                          onPressed: _pickDate,
                          icon: const Icon(Icons.calendar_today),
                          label: Text(DateFormat.yMd().format(_selectedDate)),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        const Text(
                          'Time',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextButton.icon(
                          onPressed: _pickTime,
                          icon: const Icon(Icons.access_time),
                          label: Text(_selectedTime.format(context)),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitClass,
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
