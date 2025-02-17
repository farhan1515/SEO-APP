import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:seo_app/theme/text_style.dart';
import '../models/recurring_schedule.dart';

class RecurringScheduleDialog extends StatefulWidget {
  final RecurringSchedule? initialSchedule;
  final Function(RecurringSchedule) onSave;

  const RecurringScheduleDialog({
    Key? key,
    this.initialSchedule,
    required this.onSave,
  }) : super(key: key);

  @override
  State<RecurringScheduleDialog> createState() =>
      _RecurringScheduleDialogState();
}

class _RecurringScheduleDialogState extends State<RecurringScheduleDialog> {
  late String _frequency;
  late List<String> _selectedWeekdays;
  DateTime? _endDate;

  final List<String> _frequencies = ['Daily', 'Weekly', 'Monthly', 'Yearly'];
  final List<Map<String, String>> _weekdays = [
    {'short': 'M', 'full': 'Mon'},
    {'short': 'TU', 'full': 'Tue'},
    {'short': 'W', 'full': 'Wed'},
    {'short': 'TH', 'full': 'Thu'},
    {'short': 'F', 'full': 'Fri'},
    {'short': 'SA', 'full': 'Sat'}, // Changed from 'S' to 'SA'
    {'short': 'SU', 'full': 'Sun'},
  ];

  @override
  void initState() {
    super.initState();
    _frequency = widget.initialSchedule?.frequency ?? 'Weekly';
    _selectedWeekdays = widget.initialSchedule?.weekdays ?? [];
    _endDate = widget.initialSchedule?.endDate;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recurring Schedule',
                    style: lexand.copyWith(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFEC4899), // Pink-600
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFFEC4899)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Frequency Dropdown
              Text(
                'Frequency',
                style: headsmall.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color.fromARGB(255, 229, 155, 197), // Pink-100
                    width: 2,
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _frequency,
                    isExpanded: true,
                    icon: const Icon(
                      Icons.arrow_drop_down,
                      color: Color(0xFFEC4899),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    borderRadius: BorderRadius.circular(12),
                    items: _frequencies.map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _frequency = newValue;
                          if (newValue != 'Weekly') {
                            _selectedWeekdays.clear();
                          }
                        });
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Weekday Selector
              if (_frequency == 'Weekly') ...[
                Text(
                  'Repeat on',
                  style: headsmall.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _weekdays.map((day) {
                    final isSelected = _selectedWeekdays.contains(day['short']);
                    return InkWell(
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            _selectedWeekdays.remove(day['short']);
                          } else {
                            _selectedWeekdays.add(day['short']!);
                          }
                        });
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected
                              ? const Color(0xFFEC4899)
                              : const Color(0xFFFCE7F3),
                        ),
                        child: Center(
                          child: Text(
                            day['full']!,
                            style: texts.copyWith(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: isSelected
                                  ? Colors.white
                                  : const Color(0xFFEC4899),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
              ],

              // End Date Selector
              Text(
                'End Date',
                style: headsmall.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () async {
                  final DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: _endDate ?? DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                    builder: (context, child) {
                      return Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: const ColorScheme.light(
                            primary: Color(0xFFEC4899),
                            onPrimary: Colors.white,
                            surface: Colors.white,
                            onSurface: Colors.black,
                          ),
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (picked != null) {
                    setState(() {
                      _endDate = picked;
                    });
                  }
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color.fromARGB(255, 229, 155, 197),
                      width: 2,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        size: 20,
                        color: Color(0xFFEC4899),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _endDate != null
                            ? DateFormat('MM/dd/yyyy').format(_endDate!)
                            : 'No end date',
                        style: headsmall.copyWith(
                          fontSize: 16,
                          color: _endDate != null
                              ? Colors.black87
                              : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey,
                    ),
                    child: Text(
                      'Cancel',
                      style: lexand.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: () {
                      widget.onSave(
                        RecurringSchedule(
                          frequency: _frequency,
                          weekdays: _selectedWeekdays,
                          endDate: _endDate,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEC4899),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Save',
                      style: lexand.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
