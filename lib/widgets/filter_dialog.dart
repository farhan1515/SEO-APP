import 'package:flutter/material.dart';
import '../theme/text_style.dart';

class FilterDialog extends StatefulWidget {
  final Function(Map<String, dynamic>) onApplyFilters;
  final List<String> allProfileNames;

  const FilterDialog({
    Key? key,
    required this.onApplyFilters,
    required this.allProfileNames,
  }) : super(key: key);

  @override
  _FilterDialogState createState() => _FilterDialogState();
}

class _FilterDialogState extends State<FilterDialog> {
  String? _selectedFilterType = 'profile_name';
  String? _selectedProfile;
  String _searchText = '';
  DateTime? _selectedDate;

  @override
  Widget build(BuildContext context) {
    final uniqueProfileNames = widget.allProfileNames.toSet().toList();

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 10.0,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.filter_list, color: Color(0xFF3E1885), size: 24),
                SizedBox(width: 12),
                Text(
                  'Filter Posts',
                  style: mont.copyWith(
                    color: Color(0xFF3E1885),
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Spacer(),
                IconButton(
                  icon: Icon(Icons.close, color: Colors.grey),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(),
                ),
              ],
            ),
            Divider(color: Colors.grey.shade300, thickness: 1),
            SizedBox(height: 16),

            // Filter Type Selector
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 16, top: 12),
                    child: Text(
                      'Filter by',
                      style: mont.copyWith(
                        color: Colors.grey.shade700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildFilterOption(
                          'Profile', 'profile_name', Icons.person_outline),
                      _buildFilterOption('Title', 'title', Icons.title),
                      _buildFilterOption(
                          'Date', 'scheduled_date', Icons.calendar_today),
                    ],
                  ),
                  SizedBox(height: 12),
                ],
              ),
            ),
            SizedBox(height: 24),

            // Filter Content
            AnimatedSwitcher(
              duration: Duration(milliseconds: 300),
              child: _buildFilterContent(uniqueProfileNames),
            ),

            SizedBox(height: 24),

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text(
                    'Cancel',
                    style: mont.copyWith(
                      color: Colors.grey.shade700,
                      fontSize: 16,
                    ),
                  ),
                ),
                SizedBox(width: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF3E1885),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  onPressed: () {
                    final filters = {
                      'filterType': _selectedFilterType,
                      'profileName': _selectedProfile,
                      'title': _searchText,
                      'date': _selectedDate,
                    };
                    widget.onApplyFilters(filters);
                    Navigator.pop(context);
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check, size: 18, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        'Apply Filters',
                        style: mont.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterOption(String label, String value, IconData icon) {
    final isSelected = _selectedFilterType == value;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedFilterType = value;
          _selectedProfile = null;
          _searchText = '';
          _selectedDate = null;
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? Color(0xFF3E1885).withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isSelected
              ? Border.all(color: Color(0xFF3E1885), width: 1.5)
              : Border.all(color: Colors.transparent),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Color(0xFF3E1885) : Colors.grey.shade600,
              size: 24,
            ),
            SizedBox(height: 6),
            Text(
              label,
              style: mont.copyWith(
                color: isSelected ? Color(0xFF3E1885) : Colors.grey.shade700,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterContent(List<String> uniqueProfileNames) {
    switch (_selectedFilterType) {
      case 'profile_name':
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: DropdownButtonFormField<String>(
            value: _selectedProfile,
            decoration: InputDecoration(
              labelText: 'Select Profile',
              labelStyle: mont.copyWith(color: Colors.grey.shade700),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              filled: true,
              fillColor: Colors.white,
              prefixIcon: Icon(Icons.person, color: Color(0xFF3E1885)),
            ),
            icon: Icon(Icons.arrow_drop_down, color: Color(0xFF3E1885)),
            dropdownColor: Colors.white,
            borderRadius: BorderRadius.circular(12),
            isExpanded: true,
            hint: Text('Choose a profile'),
            items: uniqueProfileNames
                .map<DropdownMenuItem<String>>((String profile) {
              return DropdownMenuItem<String>(
                value: profile,
                child: Text(
                  profile,
                  style: mont.copyWith(
                    color: Colors.black87,
                    fontSize: 16,
                  ),
                ),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedProfile = value;
              });
            },
          ),
        );
      case 'title':
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: TextField(
            decoration: InputDecoration(
              labelText: 'Search by title',
              labelStyle: mont.copyWith(color: Colors.grey.shade700),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              filled: true,
              fillColor: Colors.white,
              hintText: 'Enter post title keywords',
              hintStyle: mont.copyWith(color: Colors.grey.shade400),
              prefixIcon: Icon(Icons.search, color: Color(0xFF3E1885)),
            ),
            style: mont.copyWith(
              fontSize: 16,
              color: Colors.black87,
            ),
            onChanged: (value) {
              setState(() {
                _searchText = value;
              });
            },
          ),
        );
      case 'scheduled_date':
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: ListTile(
            leading: Icon(
              Icons.calendar_today,
              color: Color(0xFF3E1885),
            ),
            title: Text(
              _selectedDate == null
                  ? 'Select a date'
                  : '${_selectedDate!.toLocal().toString().split(' ')[0]}',
              style: mont.copyWith(
                color: _selectedDate == null
                    ? Colors.grey.shade600
                    : Colors.black87,
                fontSize: 16,
              ),
            ),
            trailing: _selectedDate != null
                ? IconButton(
                    icon: Icon(Icons.clear, color: Colors.grey),
                    onPressed: () {
                      setState(() {
                        _selectedDate = null;
                      });
                    },
                  )
                : Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            contentPadding: EdgeInsets.symmetric(horizontal: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onTap: () async {
              final DateTime? picked = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: ColorScheme.light(
                        primary: Color(0xFF3E1885),
                        onPrimary: Colors.white,
                        onSurface: Colors.black,
                      ),
                      textButtonTheme: TextButtonThemeData(
                        style: TextButton.styleFrom(
                          foregroundColor: Color(0xFF3E1885),
                        ),
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
              }
            },
          ),
        );
      default:
        return SizedBox.shrink();
    }
  }
}
