import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class HomeSearchToolbar extends StatefulWidget {
  final String initialQuery;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchCleared;
  final int activeFilterCount;
  final VoidCallback onOpenFilter;
  final VoidCallback? onSubmitted;

  const HomeSearchToolbar({
    super.key,
    required this.initialQuery,
    required this.onSearchChanged,
    required this.onSearchCleared,
    required this.activeFilterCount,
    required this.onOpenFilter,
    this.onSubmitted,
  });

  @override
  State<HomeSearchToolbar> createState() => _HomeSearchToolbarState();
}

class _HomeSearchToolbarState extends State<HomeSearchToolbar> {
  late final TextEditingController _textController;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.initialQuery);
  }

  @override
  void didUpdateWidget(covariant HomeSearchToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialQuery != oldWidget.initialQuery &&
        _textController.text != widget.initialQuery) {
      _textController.value = TextEditingValue(
        text: widget.initialQuery,
        selection: TextSelection.collapsed(offset: widget.initialQuery.length),
      );
    }
  }

  void _onChanged(String val) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 250), () {
      if (mounted) {
        widget.onSearchChanged(val);
      }
    });
    setState(() {}); // to show/hide clear icon
  }

  void _onClear() {
    _debounceTimer?.cancel();
    _textController.clear();
    widget.onSearchCleared();
    setState(() {});
  }

  void _onSubmit(String val) {
    _debounceTimer?.cancel();
    widget.onSearchChanged(val);
    widget.onSubmitted?.call();
    FocusScope.of(context).unfocus();
  }

  void _openFilterWithFlush() {
    if (_debounceTimer?.isActive == true) {
      _debounceTimer?.cancel();
      widget.onSearchChanged(_textController.text);
    }
    widget.onOpenFilter();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: Row(
        children: [
          // Search TextField
          Expanded(
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: TextField(
                controller: _textController,
                textInputAction: TextInputAction.search,
                onChanged: _onChanged,
                onSubmitted: _onSubmit,
                decoration: InputDecoration(
                  hintText: 'Tìm tên giải, địa điểm',
                  hintStyle: const TextStyle(
                    color: AppColors.textHint,
                    fontSize: 14,
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: AppColors.primary,
                    size: 22,
                  ),
                  suffixIcon: _textController.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          tooltip: 'Xóa tìm kiếm',
                          onPressed: _onClear,
                        ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 13,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Filter Button with Badge
          Material(
            color: widget.activeFilterCount > 0
                ? AppColors.primaryLight
                : AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _openFilterWithFlush,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: widget.activeFilterCount > 0
                        ? AppColors.primary
                        : AppColors.border,
                  ),
                ),
                alignment: Alignment.center,
                child: Badge.count(
                  count: widget.activeFilterCount,
                  isLabelVisible: widget.activeFilterCount > 0,
                  backgroundColor: AppColors.primary,
                  textColor: Colors.white,
                  child: Icon(
                    Icons.tune_rounded,
                    color: widget.activeFilterCount > 0
                        ? AppColors.primary
                        : AppColors.textPrimary,
                    size: 22,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
