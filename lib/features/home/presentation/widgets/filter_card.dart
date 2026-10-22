import 'package:flutter/material.dart';
import '../controller/home_controller.dart';

class FilterCard extends StatefulWidget {
  final HomeController controller;
  const FilterCard({super.key, required this.controller});
  @override
  State<FilterCard> createState() => _FilterCardState();
}

class _FilterCardState extends State<FilterCard> {
  late final TextEditingController text;
  @override
  void initState() {
    super.initState();
    text = TextEditingController(text: widget.controller.searchQuery);
  }

  @override
  void didUpdateWidget(covariant FilterCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (text.text != widget.controller.searchQuery) {
      text.value = TextEditingValue(
        text: widget.controller.searchQuery,
        selection: TextSelection.collapsed(
          offset: widget.controller.searchQuery.length,
        ),
      );
    }
  }

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            TextField(
              controller: text,
              onChanged: c.setSearchQuery,
              decoration: InputDecoration(
                labelText: 'Tìm tên giải hoặc địa điểm',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: text.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () => c.setSearchQuery(''),
                        icon: const Icon(Icons.clear),
                      ),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            _dropdown(c.selectedDistance, c.distanceOptions, c.setDistance),
            _dropdown(c.selectedLocation, c.locationOptions, c.setLocation),
            _dropdown(c.selectedTime, c.timeOptions, c.setTime),
            _dropdown(c.selectedStatus, c.statusOptions, c.setStatus),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: c.resetFilters,
                child: const Text('Đặt lại bộ lọc'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dropdown(
    String value,
    List<String> values,
    ValueChanged<String> changed,
  ) => DropdownButton<String>(
    value: value,
    isExpanded: true,
    items: values
        .map(
          (s) => DropdownMenuItem(
            value: s,
            child: Text(s, overflow: TextOverflow.ellipsis),
          ),
        )
        .toList(),
    onChanged: (v) {
      if (v != null) changed(v);
    },
  );
}
