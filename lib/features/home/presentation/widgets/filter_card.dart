import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../controller/home_controller.dart';

class FilterCard extends StatefulWidget {
  final HomeController controller;

  const FilterCard({super.key, required this.controller});

  @override
  State<FilterCard> createState() => _FilterCardState();
}

class _FilterCardState extends State<FilterCard> {
  late TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // 1. Text Search Input
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Row(
              children: [
                const Icon(
                  Icons.search_rounded,
                  color: Color(0xFF1E293B),
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _textController,
                    onChanged: (val) => widget.controller.setSearchQuery(val),
                    decoration: InputDecoration(
                      hintText: 'Nhập tên sự kiện',
                      hintStyle: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                if (_textController.text.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _textController.clear();
                      widget.controller.setSearchQuery('');
                    },
                    child: const Icon(Icons.close_rounded, size: 18, color: Colors.grey),
                  ),
              ],
            ),
          ),

          const Divider(height: 1, color: AppColors.border),

          // 2. Dropdown "- Cự ly -"
          _buildDropdownRow(
            value: widget.controller.selectedDistance,
            options: widget.controller.distanceOptions,
            onChanged: (val) {
              if (val != null) widget.controller.setDistance(val);
            },
          ),

          const Divider(height: 1, color: AppColors.border),

          // 3. Dropdown "- Địa điểm -"
          _buildDropdownRow(
            value: widget.controller.selectedLocation,
            options: widget.controller.locationOptions,
            onChanged: (val) {
              if (val != null) widget.controller.setLocation(val);
            },
          ),

          const Divider(height: 1, color: AppColors.border),

          // 4. Dropdown "- Thời gian -"
          _buildDropdownRow(
            value: widget.controller.selectedTime,
            options: widget.controller.timeOptions,
            onChanged: (val) {
              if (val != null) widget.controller.setTime(val);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownRow({
    required String value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Color(0xFF1E293B),
            size: 22,
          ),
          items: options.map((opt) {
            final isDefault = opt.startsWith('-');
            return DropdownMenuItem<String>(
              value: opt,
              child: Text(
                opt,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isDefault ? FontWeight.w400 : FontWeight.w500,
                  color: isDefault ? AppColors.textSecondary : AppColors.textPrimary,
                ),
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
