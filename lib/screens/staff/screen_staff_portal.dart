import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/provider_user_profile.dart';
import '../../providers/provider_gym_class.dart';
import '../../models/gym_class.dart';
import '../../main.dart';

class ScreenStaffPortal extends ConsumerWidget {
  static const routeName = '/staff_portal';

  const ScreenStaffPortal({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfile = ref.watch(providerUserProfile);
    final gymClassProvider = ref.watch(providerGymClass);
    final classes = gymClassProvider.classes;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Staff Portal',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Welcome back, ${userProfile.firstName}!',
                      style: const TextStyle(fontSize: 18, color: Colors.black54),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () => _showCreateClassDialog(context, ref),
                  icon: const Icon(Icons.add),
                  label: const Text('Create Class'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            
            // Stats Row
            Row(
              children: [
                _buildStatCard('Active Classes', '${classes.length}', Icons.class_, Colors.blue),
                const SizedBox(width: 16),
                _buildStatCard('Total Members', '245', Icons.people, Colors.green),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildStatCard('Pending Registrations', '45', Icons.pending_actions, Colors.orange),
                const SizedBox(width: 16),
                _buildStatCard('Gym Capacity', '75%', Icons.pie_chart, Colors.purple),
              ],
            ),
            
            const SizedBox(height: 40),
            const Text(
              'Class Management',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            if (gymClassProvider.isLoading)
              const Center(child: CircularProgressIndicator())
            else if (classes.isEmpty)
              const Center(child: Text('No classes created yet.'))
            else
              ...classes.map((c) => _buildManagementItem(
                context,
                ref,
                c.id,
                c.title,
                c.instructor,
                c.timeText,
                '${c.filled}/${c.capacity}',
              )).toList(),
          ],
        ),
      ),
    );
  }

  void _showCreateClassDialog(BuildContext context, WidgetRef ref) {
    final titleController = TextEditingController();
    final instructorController = TextEditingController();
    final locationController = TextEditingController();
    final capacityController = TextEditingController();
    final durationController = TextEditingController(text: '60');
    DateTime selectedDate = DateTime.now();
    TimeOfDay selectedTime = TimeOfDay.now();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Create New Class'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Class Title')),
                TextField(controller: instructorController, decoration: const InputDecoration(labelText: 'Instructor')),
                TextField(controller: locationController, decoration: const InputDecoration(labelText: 'Location')),
                TextField(
                  controller: capacityController, 
                  decoration: const InputDecoration(labelText: 'Capacity'),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: durationController, 
                  decoration: const InputDecoration(labelText: 'Duration (min)'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (date != null) setState(() => selectedDate = date);
                        },
                        child: Text('${selectedDate.month}/${selectedDate.day}/${selectedDate.year}'),
                      ),
                    ),
                    Expanded(
                      child: TextButton(
                        onPressed: () async {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: selectedTime,
                          );
                          if (time != null) setState(() => selectedTime = time);
                        },
                        child: Text(selectedTime.format(context)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final newClass = GymClass(
                  id: '', // Firestore will generate this
                  title: titleController.text,
                  instructor: instructorController.text,
                  dateTime: DateTime(
                    selectedDate.year,
                    selectedDate.month,
                    selectedDate.day,
                    selectedTime.hour,
                    selectedTime.minute,
                  ),
                  durationMinutes: int.tryParse(durationController.text) ?? 60,
                  location: locationController.text,
                  capacity: int.tryParse(capacityController.text) ?? 20,
                  filled: 0,
                  status: ClassStatus.open,
                );
                ref.read(providerGymClass).addClass(newClass);
                Navigator.pop(context);
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(height: 12),
            Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            Text(label, style: TextStyle(fontSize: 14, color: Colors.black.withOpacity(0.6))),
          ],
        ),
      ),
    );
  }

  Widget _buildManagementItem(BuildContext context, WidgetRef ref, String id, String title, String instructor, String time, String filled) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text('$instructor • $time', style: const TextStyle(color: Colors.black54)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(filled, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
              const Text('Filled', style: TextStyle(fontSize: 12, color: Colors.black45)),
            ],
          ),
          const SizedBox(width: 16),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Delete Class'),
                  content: const Text('Are you sure you want to delete this class?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                    TextButton(
                      onPressed: () {
                        ref.read(providerGymClass).deleteClass(id);
                        Navigator.pop(context);
                      }, 
                      child: const Text('Delete', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
