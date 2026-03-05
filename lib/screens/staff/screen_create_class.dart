import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../main.dart';
import '../../models/gym_class.dart';

class ScreenCreateClass extends ConsumerStatefulWidget {
  static const routeName = '/staff_create_class';

  const ScreenCreateClass({super.key});

  @override
  ConsumerState<ScreenCreateClass> createState() => _ScreenCreateClassState();
}

class _ScreenCreateClassState extends ConsumerState<ScreenCreateClass> {
  final _titleController = TextEditingController();
  final _instructorController = TextEditingController();
  final _locationController = TextEditingController();
  final _capacityController = TextEditingController();
  final _durationController = TextEditingController(text: '60');

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _instructorController.dispose();
    _locationController.dispose();
    _capacityController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      setState(() {
        _selectedDate = date;
      });
    }
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (time != null) {
      setState(() {
        _selectedTime = time;
      });
    }
  }

  Future<void> _createClass() async {
    if (_isSubmitting) return;
    if (_titleController.text.trim().isEmpty ||
        _instructorController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter at least title and instructor.'),
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final newClass = GymClass(
      id: '',
      title: _titleController.text.trim(),
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
      capacity: int.tryParse(_capacityController.text.trim()) ?? 20,
      filled: 0,
      status: ClassStatus.open,
    );

    try {
      await ref.read(providerGymClass).addClass(newClass);
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
      appBar: AppBar(title: const Text('Create New Class')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Class Title'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _instructorController,
              decoration: const InputDecoration(labelText: 'Instructor'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _locationController,
              decoration: const InputDecoration(labelText: 'Location'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _capacityController,
              decoration: const InputDecoration(labelText: 'Capacity'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _durationController,
              decoration: const InputDecoration(labelText: 'Duration (min)'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 20),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today_outlined),
              title: const Text('Date'),
              subtitle: Text(
                '${_selectedDate.month}/${_selectedDate.day}/${_selectedDate.year}',
              ),
              onTap: _pickDate,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.access_time),
              title: const Text('Time'),
              subtitle: Text(_selectedTime.format(context)),
              onTap: _pickTime,
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _createClass,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Create Class'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
