import 'dart:typed_data';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../db_helpers/db_gym_class.dart';
import '../../main.dart';
import '../../models/gym_class.dart';
import '../../util/classes/class_visuals.dart';

class ScreenCreateClass extends ConsumerStatefulWidget {
  static const routeName = '/staff/create-class';
  final GymClass? existingClass;

  const ScreenCreateClass({super.key, this.existingClass});

  @override
  ConsumerState<ScreenCreateClass> createState() => _ScreenCreateClassState();
}

class _ScreenCreateClassState extends ConsumerState<ScreenCreateClass> {
  static const int _maxClassPhotos = 4;

  final _formKey = GlobalKey<FormState>();
  final ImagePicker _imagePicker = ImagePicker();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _instructorController = TextEditingController();
  final _locationController = TextEditingController();
  final _capacityController = TextEditingController();
  final _durationController = TextEditingController(text: '60');
  final _repeatEveryWeeksController = TextEditingController(text: '1');
  final _occurrenceCountController = TextEditingController(text: '4');

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  String _selectedType = gymClassTypes.first;
  late String _selectedIconKey;
  List<String> _existingImageUrls = <String>[];
  final List<_PendingClassPhoto> _pendingPhotos = <_PendingClassPhoto>[];
  bool _isSubmitting = false;
  bool _repeatClass = false;
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
    _selectedIconKey = defaultGymClassIconKeyForType(_selectedType);
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
    _selectedIconKey = existingClass.iconKey;
    _existingImageUrls = List<String>.from(existingClass.imageUrls);
    _selectedDate = existingClass.dateTime;
    _selectedTime = TimeOfDay.fromDateTime(existingClass.dateTime);
    _repeatClass = existingClass.isRecurring;
    _repeatEveryWeeksController.text = existingClass.recurrenceIntervalWeeks
        .toString();
    _occurrenceCountController.text = existingClass.recurrenceCount.toString();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _instructorController.dispose();
    _locationController.dispose();
    _capacityController.dispose();
    _durationController.dispose();
    _repeatEveryWeeksController.dispose();
    _occurrenceCountController.dispose();
    super.dispose();
  }

  int get _repeatEveryWeeks =>
      int.tryParse(_repeatEveryWeeksController.text.trim()) ?? 1;

  int get _occurrenceCount =>
      int.tryParse(_occurrenceCountController.text.trim()) ?? 1;

  int get _remainingPhotoSlots =>
      _maxClassPhotos - _existingImageUrls.length - _pendingPhotos.length;

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

  Future<void> _pickClassImages() async {
    if (_remainingPhotoSlots <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You can add up to 4 class photos.'),
        ),
      );
      return;
    }

    final pickedFiles = await _imagePicker.pickMultiImage(
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (pickedFiles.isEmpty) {
      return;
    }

    final limitedFiles = pickedFiles.take(_remainingPhotoSlots).toList();
    final uploadedPhotos = <_PendingClassPhoto>[];

    for (final file in limitedFiles) {
      final bytes = await file.readAsBytes();
      uploadedPhotos.add(
        _PendingClassPhoto(name: file.name, bytes: bytes),
      );
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _pendingPhotos.addAll(uploadedPhotos);
    });

    if (pickedFiles.length > limitedFiles.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only the first 4 class photos were kept.'),
        ),
      );
    }
  }

  Future<List<String>> _uploadPendingClassImages() async {
    if (_pendingPhotos.isEmpty) {
      return const <String>[];
    }

    final titleSeed = _titleController.text.trim().isEmpty
        ? _selectedType
        : _titleController.text.trim();
    final uploadedUrls = <String>[];

    for (var index = 0; index < _pendingPhotos.length; index++) {
      final photo = _pendingPhotos[index];
      final imageUrl = await DBGymClass.uploadClassImage(
        imageBytes: photo.bytes,
        imageId: '$titleSeed-${photo.name}-$index',
      );
      uploadedUrls.add(imageUrl);
    }

    return uploadedUrls;
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

    try {
      final existingClass = widget.existingClass;
      final capacity = int.tryParse(_capacityController.text.trim()) ?? 20;
      final filled = existingClass == null
          ? 0
          : existingClass.filled.clamp(0, capacity);
      final occurrenceCount = !_isEditing && _repeatClass ? _occurrenceCount : 1;
      final repeatEveryWeeks = !_isEditing && _repeatClass
          ? _repeatEveryWeeks
          : 1;

      List<String> uploadedImageUrls;
      try {
        uploadedImageUrls = await _uploadPendingClassImages();
      } on FirebaseException catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Photo Upload Error (${e.code}): ${e.message ?? 'Unknown error occurred'}',
            ),
          ),
        );
        return;
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Photo Upload Error: $e')),
        );
        return;
      }

      final classToSave = GymClass(
        id: existingClass?.id ?? '',
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        type: _selectedType,
        iconKey: _selectedIconKey,
        imageUrls: <String>[..._existingImageUrls, ...uploadedImageUrls],
        instructor: _instructorController.text.trim(),
        dateTime: _selectedDateTime,
        durationMinutes: int.tryParse(_durationController.text.trim()) ?? 60,
        location: _locationController.text.trim(),
        capacity: capacity,
        filled: filled,
        recurrenceSeriesId: existingClass?.recurrenceSeriesId,
        recurrenceCount: existingClass?.recurrenceCount ?? occurrenceCount,
        recurrenceIntervalWeeks:
            existingClass?.recurrenceIntervalWeeks ?? repeatEveryWeeks,
        recurrenceIndex: existingClass?.recurrenceIndex ?? 0,
      );

      try {
        if (_isEditing) {
          await ref.read(providerGymClass).updateClass(classToSave);
        } else {
          await ref.read(providerGymClass).addClass(
                classToSave,
                occurrenceCount: occurrenceCount,
                repeatEveryWeeks: repeatEveryWeeks,
              );
        }
      } on FirebaseException catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Class Save Error (${e.code}): ${e.message ?? 'Unknown error occurred'}',
            ),
          ),
        );
        return;
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Class Save Error: $e')),
        );
        return;
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
    final repeatEveryWeeks = _repeatEveryWeeks;
    final occurrenceCount = _occurrenceCount;
    final recurrenceSummary = occurrenceCount > 1
        ? (repeatEveryWeeks == 1
              ? 'Repeats weekly for $occurrenceCount sessions.'
              : 'Repeats every $repeatEveryWeeks weeks for $occurrenceCount sessions.')
        : 'Single occurrence only.';

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
                    setState(() {
                      final previousType = _selectedType;
                      final previousDefault = defaultGymClassIconKeyForType(
                        previousType,
                      );
                      _selectedType = value;
                      if (_selectedIconKey == previousDefault) {
                        _selectedIconKey = defaultGymClassIconKeyForType(value);
                      }
                    });
                  },
                  validator: (value) => value == null || value.isEmpty
                      ? 'Please select a class type'
                      : null,
                ),
                const SizedBox(height: 20),
                Text(
                  'Home Screen Icon',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Choose the icon members will see on the home class cards.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: gymClassVisualOptions.map((option) {
                    final isSelected = option.key == _selectedIconKey;
                    return _ClassIconChoiceChip(
                      option: option,
                      selected: isSelected,
                      onTap: () {
                        setState(() {
                          _selectedIconKey = option.key;
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                Text(
                  'Class Photos',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Add up to 4 photos to show on the class detail screen header.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _isSubmitting ? null : _pickClassImages,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: Text(
                    _remainingPhotoSlots > 0
                        ? 'Add Photos ($_remainingPhotoSlots left)'
                        : 'Photo Limit Reached',
                  ),
                ),
                const SizedBox(height: 12),
                if (_existingImageUrls.isNotEmpty || _pendingPhotos.isNotEmpty)
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (var index = 0; index < _existingImageUrls.length; index++)
                        _ClassImagePreview(
                          imageProvider: NetworkImage(_existingImageUrls[index]),
                          onRemove: () {
                            setState(() {
                              _existingImageUrls.removeAt(index);
                            });
                          },
                        ),
                      for (var index = 0; index < _pendingPhotos.length; index++)
                        _ClassImagePreview(
                          imageProvider: MemoryImage(_pendingPhotos[index].bytes),
                          label: 'New',
                          onRemove: () {
                            setState(() {
                              _pendingPhotos.removeAt(index);
                            });
                          },
                        ),
                    ],
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: colorScheme.outlineVariant),
                    ),
                    child: Text(
                      'No class photos added yet.',
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
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
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: colorScheme.outlineVariant),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.repeat_rounded,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Repeat Schedule',
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ),
                          Switch.adaptive(
                            value: _repeatClass,
                            onChanged: _isEditing
                                ? null
                                : (value) {
                                    setState(() {
                                      _repeatClass = value;
                                      if (value && _occurrenceCount < 2) {
                                        _occurrenceCountController.text = '4';
                                      }
                                    });
                                  },
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _isEditing && widget.existingClass?.isRecurring == true
                            ? 'This class belongs to a recurring series. Saving changes here updates only this occurrence.'
                            : 'Create repeating weekly sessions while keeping each occurrence bookable on its own.',
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                      if (!_isEditing && _repeatClass) ...[
                        const SizedBox(height: 16),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final useVerticalLayout =
                                constraints.maxWidth < 460;

                            final repeatEveryField = TextFormField(
                              controller: _repeatEveryWeeksController,
                              decoration: const InputDecoration(
                                labelText: 'Repeat (weeks)',
                                prefixIcon: Icon(Icons.repeat_one_rounded),
                              ),
                              onChanged: (_) => setState(() {}),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (!_repeatClass) {
                                  return null;
                                }
                                return _validatePositiveNumber(
                                  value,
                                  emptyMessage: 'Enter repeat interval',
                                  invalidMessage:
                                      'Repeat interval must be at least 1 week',
                                  minValue: 1,
                                );
                              },
                            );

                            final totalSessionsField = TextFormField(
                              controller: _occurrenceCountController,
                              decoration: const InputDecoration(
                                labelText: 'Sessions',
                                prefixIcon: Icon(Icons.event_repeat_rounded),
                              ),
                              onChanged: (_) => setState(() {}),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (!_repeatClass) {
                                  return null;
                                }
                                return _validatePositiveNumber(
                                  value,
                                  emptyMessage: 'Enter total sessions',
                                  invalidMessage:
                                      'Series must include at least 2 sessions',
                                  minValue: 2,
                                );
                              },
                            );

                            if (useVerticalLayout) {
                              return Column(
                                children: [
                                  repeatEveryField,
                                  const SizedBox(height: 12),
                                  totalSessionsField,
                                ],
                              );
                            }

                            return Row(
                              children: [
                                Expanded(child: repeatEveryField),
                                const SizedBox(width: 16),
                                Expanded(child: totalSessionsField),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        Text(
                          recurrenceSummary,
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            height: 1.4,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ] else if (_isEditing &&
                          widget.existingClass?.isRecurring == true) ...[
                        const SizedBox(height: 12),
                        Text(
                          widget.existingClass!.recurrenceSummary,
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            height: 1.4,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
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

class _PendingClassPhoto {
  final String name;
  final Uint8List bytes;

  const _PendingClassPhoto({required this.name, required this.bytes});
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

class _ClassIconChoiceChip extends StatelessWidget {
  final GymClassVisualOption option;
  final bool selected;
  final VoidCallback onTap;

  const _ClassIconChoiceChip({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          width: 104,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(colors: option.colors),
            border: Border.all(
              color: selected ? colorScheme.primary : Colors.transparent,
              width: 2,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      blurRadius: 14,
                      offset: const Offset(0, 8),
                      color: option.colors.last.withValues(alpha: 0.28),
                    ),
                  ]
                : null,
          ),
          child: Column(
            children: [
              Icon(option.icon, color: Colors.white, size: 28),
              const SizedBox(height: 10),
              Text(
                option.label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClassImagePreview extends StatelessWidget {
  final ImageProvider imageProvider;
  final VoidCallback onRemove;
  final String? label;

  const _ClassImagePreview({
    required this.imageProvider,
    required this.onRemove,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Image(
            image: imageProvider,
            width: 110,
            height: 110,
            fit: BoxFit.cover,
          ),
        ),
        if (label != null)
          Positioned(
            left: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                label!,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        Positioned(
          top: 6,
          right: 6,
          child: Material(
            color: Colors.black.withValues(alpha: 0.5),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onRemove,
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(Icons.close_rounded, color: Colors.white, size: 18),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
