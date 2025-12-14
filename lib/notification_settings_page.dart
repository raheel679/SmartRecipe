import 'package:flutter/material.dart';

class NotificationSettingsPage extends StatefulWidget {
  final bool initialEnabled;
  final TimeOfDay initialBreakfast;
  final TimeOfDay initialLunch;
  final TimeOfDay initialDinner;
  final Function(bool enabled, TimeOfDay breakfast, TimeOfDay lunch, TimeOfDay dinner) onSettingsChanged;

  const NotificationSettingsPage({
    super.key,
    required this.initialEnabled,
    required this.initialBreakfast,
    required this.initialLunch,
    required this.initialDinner,
    required this.onSettingsChanged,
  });

  @override
  State<NotificationSettingsPage> createState() => _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  late bool _enabled;
  late TimeOfDay _breakfast;
  late TimeOfDay _lunch;
  late TimeOfDay _dinner;

  @override
  void initState() {
    super.initState();
    _enabled = widget.initialEnabled;
    _breakfast = widget.initialBreakfast;
    _lunch = widget.initialLunch;
    _dinner = widget.initialDinner;
  }

  Future<void> _pickTime(BuildContext context, TimeOfDay initialTime, Function(TimeOfDay) onPicked) async {
    final picked = await showTimePicker(context: context, initialTime: initialTime);
    if (picked != null) onPicked(picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notification Settings')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SwitchListTile(
              title: const Text('Enable Notifications'),
              value: _enabled,
              onChanged: (val) => setState(() => _enabled = val),
            ),
            ListTile(
              title: const Text('Breakfast Time'),
              trailing: Text(_breakfast.format(context)),
              onTap: () => _pickTime(context, _breakfast, (val) => setState(() => _breakfast = val)),
            ),
            ListTile(
              title: const Text('Lunch Time'),
              trailing: Text(_lunch.format(context)),
              onTap: () => _pickTime(context, _lunch, (val) => setState(() => _lunch = val)),
            ),
            ListTile(
              title: const Text('Dinner Time'),
              trailing: Text(_dinner.format(context)),
              onTap: () => _pickTime(context, _dinner, (val) => setState(() => _dinner = val)),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () {
                widget.onSettingsChanged(_enabled, _breakfast, _lunch, _dinner);
                Navigator.pop(context);
              },
              child: const Text('Save'),
            )
          ],
        ),
      ),
    );
  }
}
