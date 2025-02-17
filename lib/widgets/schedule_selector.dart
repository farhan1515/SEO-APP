import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:seo_app/models/recurring_schedule.dart';
import 'package:seo_app/theme/text_style.dart';
import 'package:seo_app/widgets/recurring_schedule_dialog.dart';
import 'package:table_calendar/table_calendar.dart';

class ScheduleSelector extends StatefulWidget {
  final Function(DateTime? date, String? time, String? timezone,
      RecurringSchedule? recurring)? onScheduleChange;

  const ScheduleSelector({
    Key? key,
    this.onScheduleChange,
  }) : super(key: key);

  @override
  State<ScheduleSelector> createState() => _ScheduleSelectorState();
}

class _ScheduleSelectorState extends State<ScheduleSelector> {
  DateTime? _selectedDate;
  String? _selectedTime;
  String? _selectedTimezone;
  RecurringSchedule? _recurringSchedule;
  bool _isRecurringDialogOpen = false;

  final List<String> _timeZones = [
    'Eastern Time (US & Canada)',
    'Pacific Time (US & Canada)',
    'India Standard Time',
    'UTC',
  ];

  void _showRecurringDialog() {
    showDialog(
      context: context,
      builder: (context) => RecurringScheduleDialog(
        initialSchedule: _recurringSchedule,
        onSave: (schedule) {
          setState(() {
            _recurringSchedule = schedule;
          });
          widget.onScheduleChange?.call(
            _selectedDate,
            _selectedTime,
            _selectedTimezone,
            schedule,
          );
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Schedule Your Time',
            style: lexand.copyWith(
              fontSize: 22,
              fontWeight: FontWeight.w200,
            )),
        const SizedBox(height: 24),
        Container(
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
          child: Padding(
            padding: const EdgeInsets.all(10.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date Field
                _buildLabel('Start Date'),
                const SizedBox(height: 8),
                _buildTextField(
                  icon: Icons.calendar_today,
                  value: _selectedDate != null
                      ? DateFormat('MM/dd/yyyy').format(_selectedDate!)
                      : null,
                  placeholder: 'Select Start date',
                  onTap: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate ?? DateTime.now(),
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
                        _selectedDate = picked;
                      });
                      widget.onScheduleChange?.call(
                        picked,
                        _selectedTime,
                        _selectedTimezone,
                        _recurringSchedule,
                      );
                    }
                  },
                ),
                const SizedBox(height: 20),

                // Time Field
                _buildLabel('Time'),
                const SizedBox(height: 8),
                _buildTextField(
                  icon: Icons.access_time,
                  value: _selectedTime,
                  placeholder: 'Select time',
                  onTap: () async {
                    final TimeOfDay? picked = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.now(),
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
                        _selectedTime =
                            '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                      });
                      widget.onScheduleChange?.call(
                        _selectedDate,
                        _selectedTime,
                        _selectedTimezone,
                        _recurringSchedule,
                      );
                    }
                  },
                ),
                const SizedBox(height: 20),

                // Timezone Field
                _buildLabel('Timezone'),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color:
                          const Color.fromARGB(255, 241, 157, 217), // Pink-100
                      width: 2,
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedTimezone,
                      isExpanded: true,
                      hint: Row(
                        children: const [
                          Icon(
                            Icons.public,
                            size: 20,
                            color: Color(0xFFEC4899),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Select timezone',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      icon: const Icon(
                        Icons.arrow_drop_down,
                        color: Color(0xFFEC4899),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      borderRadius: BorderRadius.circular(12),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _selectedTimezone = newValue;
                          });
                          widget.onScheduleChange?.call(
                            _selectedDate,
                            _selectedTime,
                            newValue,
                            _recurringSchedule,
                          );
                        }
                      },
                      items: _timeZones.map<DropdownMenuItem<String>>(
                        (String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.public,
                                  size: 20,
                                  color: Color(0xFFEC4899),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  value,
                                  style: const TextStyle(
                                    color: Colors.black87,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Recurring Button
                InkWell(
                  onTap: _showRecurringDialog,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 20,
                    ),
                    decoration: BoxDecoration(
                      color: _recurringSchedule != null
                          ? const Color(0xFFFCE7F3) // Pink-100
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFFCE7F3), // Pink-100
                        width: 2,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.repeat,
                          size: 20,
                          color: _recurringSchedule != null
                              ? const Color(0xFFEC4899)
                              : Colors.grey[800],
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _recurringSchedule != null
                              ? _recurringSchedule!.toString()
                              : 'Make it Recurring ✨',
                          style: headsmall.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: _recurringSchedule != null
                                ? const Color(0xFFEC4899)
                                : Colors.grey[700],
                          ),
                        ),
                        if (_recurringSchedule != null) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(
                              Icons.close,
                              size: 20,
                              color: Color(0xFFEC4899),
                            ),
                            onPressed: () {
                              setState(() {
                                _recurringSchedule = null;
                              });
                              widget.onScheduleChange?.call(
                                _selectedDate,
                                _selectedTime,
                                _selectedTimezone,
                                null,
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Text(text,
        style: texts.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.grey[700],
        ));
  }

  Widget _buildTextField({
    required IconData icon,
    required String? value,
    required String placeholder,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color.fromARGB(255, 241, 157, 217), // Pink-100
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: const Color(0xFFEC4899), // Pink-600
            ),
            const SizedBox(width: 8),
            Text(
              value ?? placeholder,
              style: headsmall.copyWith(
                fontSize: 16,
                color: value != null ? Colors.black87 : Colors.grey,
              ),
              // style: TextStyle(
              //   fontSize: 16,
              //   color: value != null ? Colors.black87 : Colors.grey,
              // ),
            ),
          ],
        ),
      ),
    );
  }
}
