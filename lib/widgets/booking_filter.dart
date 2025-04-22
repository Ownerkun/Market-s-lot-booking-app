import 'package:flutter/material.dart';

class BookingFilter extends StatefulWidget {
  final List<String> statuses;
  final List<String> markets;
  final Map<String, dynamic> initialFilters;
  final Function(Map<String, dynamic>) onFilterChanged;

  const BookingFilter({
    Key? key,
    required this.statuses,
    required this.markets,
    required this.initialFilters,
    required this.onFilterChanged,
  }) : super(key: key);

  @override
  _BookingFilterState createState() => _BookingFilterState();
}

class _BookingFilterState extends State<BookingFilter> {
  late Map<String, dynamic> _currentFilters;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _currentFilters = Map.from(widget.initialFilters);
    _startDate = _currentFilters['startDate'];
    _endDate = _currentFilters['endDate'];
  }

  void _applyFilters() {
    _currentFilters['startDate'] = _startDate;
    _currentFilters['endDate'] = _endDate;
    widget.onFilterChanged(_currentFilters);
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate
          ? _startDate ?? DateTime.now()
          : _endDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
      _applyFilters();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Filter Bookings',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _currentFilters['status'],
          decoration: InputDecoration(
            labelText: 'Status',
            border: OutlineInputBorder(),
          ),
          items: [
            DropdownMenuItem<String>(
              value: null,
              child: Text('All Statuses'),
            ),
            ...widget.statuses.map((status) => DropdownMenuItem<String>(
                  value: status,
                  child: Text(status),
                )),
          ],
          onChanged: (value) {
            setState(() {
              _currentFilters['status'] = value;
            });
            _applyFilters();
          },
        ),
        SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _currentFilters['market'],
          decoration: InputDecoration(
            labelText: 'Market',
            border: OutlineInputBorder(),
          ),
          items: [
            DropdownMenuItem<String>(
              value: null,
              child: Text('All Markets'),
            ),
            ...widget.markets.map((market) => DropdownMenuItem<String>(
                  value: market,
                  child: Text(market),
                )),
          ],
          onChanged: (value) {
            setState(() {
              _currentFilters['market'] = value;
            });
            _applyFilters();
          },
        ),
        SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'Start Date',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                controller: TextEditingController(
                  text: _startDate != null
                      ? '${_startDate!.day}/${_startDate!.month}/${_startDate!.year}'
                      : '',
                ),
                onTap: () => _selectDate(context, true),
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'End Date',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                controller: TextEditingController(
                  text: _endDate != null
                      ? '${_endDate!.day}/${_endDate!.month}/${_endDate!.year}'
                      : '',
                ),
                onTap: () => _selectDate(context, false),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
