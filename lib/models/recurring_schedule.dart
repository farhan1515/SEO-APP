import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class RecurringSchedule {
  final String frequency;
  final List<String> weekdays;
  final DateTime? endDate;

  RecurringSchedule({
    required this.frequency,
    required this.weekdays,
    this.endDate,
  });

  String _getWeekdayDisplay() {
    if (weekdays.isEmpty) return '';

    // Convert short codes to full names for better readability
    final Map<String, String> dayMapping = {
      'M': 'Monday',
      'TU': 'Tuesday',
      'W': 'Wednesday',
      'TH': 'Thursday',
      'F': 'Friday',
      'SA': 'Saturday', // Changed from 'S' to 'SA'
      'SU': 'Sunday', // Changed from 'S' to 'SU'
    };

    // If all weekdays are selected, show "every day"
    if (weekdays.length == 7) return 'every day';

    // If weekdays are Monday to Friday, show "weekdays"
    final weekdaySet = Set.from(['M', 'TU', 'W', 'TH', 'F']);
    if (weekdays.length == 5 &&
        weekdays.every((day) => weekdaySet.contains(day))) {
      return 'weekdays';
    }

    // For 1-3 days, show full names
    if (weekdays.length <= 2) {
      return weekdays.map((day) => dayMapping[day]).join(', ');
    }

    // For more than 3 days, show short form
    return weekdays.join(', ');
  }

  @override
  String toString() {
    final StringBuffer result = StringBuffer('Repeats ');
    result.write(frequency.toLowerCase());

    if (weekdays.isNotEmpty) {
      result.write('\non ${_getWeekdayDisplay()}'); // Added newline
    }

    if (endDate != null) {
      result.write(
          '\nuntil ${DateFormat('MMM d, yyyy').format(endDate!)}'); // Added newline
    }

    return result.toString();
  }

  Map<String, dynamic> toJson() {
    return {
      'frequency': frequency,
      'weekdays': weekdays,
      'endDate': endDate?.toIso8601String(),
    };
  }

  factory RecurringSchedule.fromJson(Map<String, dynamic> json) {
    return RecurringSchedule(
      frequency: json['frequency'],
      weekdays: List<String>.from(json['weekdays']),
      endDate: json['endDate'] != null ? DateTime.parse(json['endDate']) : null,
    );
  }
}
