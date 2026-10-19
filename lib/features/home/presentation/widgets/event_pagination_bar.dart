import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class EventPaginationBar extends StatelessWidget {
  final int currentPage;
  final int pageCount;
  final ValueChanged<int> onPageChanged;

  const EventPaginationBar({
    super.key,
    required this.currentPage,
    required this.pageCount,
    required this.onPageChanged,
  });

  Future<void> _showJumpDialog(BuildContext context) async {
    final targetPage = await showDialog<int>(
      context: context,
      builder: (_) => _JumpToPageDialog(
        initialPage: currentPage,
        pageCount: pageCount,
      ),
    );
    if (targetPage != null) {
      onPageChanged(targetPage);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (pageCount <= 1) return const SizedBox.shrink();

    final hasPrev = currentPage > 1;
    final hasNext = currentPage < pageCount;

    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Previous page button
          OutlinedButton.icon(
            onPressed: hasPrev ? () => onPageChanged(currentPage - 1) : null,
            icon: const Icon(Icons.chevron_left, size: 20),
            label: const Text('Trước'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(80, 42),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),

          // Jump to page button
          TextButton(
            onPressed: () => _showJumpDialog(context),
            style: TextButton.styleFrom(
              minimumSize: const Size(110, 42),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Trang $currentPage / $pageCount',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.arrow_drop_down,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),

          // Next page button
          OutlinedButton(
            onPressed: hasNext ? () => onPageChanged(currentPage + 1) : null,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(80, 42),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Sau'),
                SizedBox(width: 2),
                Icon(Icons.chevron_right, size: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _JumpToPageDialog extends StatefulWidget {
  final int initialPage;
  final int pageCount;

  const _JumpToPageDialog({
    required this.initialPage,
    required this.pageCount,
  });

  @override
  State<_JumpToPageDialog> createState() => _JumpToPageDialogState();
}

class _JumpToPageDialogState extends State<_JumpToPageDialog> {
  late final TextEditingController _textController;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: '${widget.initialPage}');
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _submit() {
    final page = int.tryParse(_textController.text.trim());
    if (page == null || page < 1 || page > widget.pageCount) {
      setState(() {
        _errorText = 'Vui lòng nhập số từ 1 đến ${widget.pageCount}';
      });
    } else {
      Navigator.pop(context, page);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Đi tới trang'),
      content: TextField(
        controller: _textController,
        keyboardType: TextInputType.number,
        autofocus: true,
        decoration: InputDecoration(
          labelText: 'Số trang (1 – ${widget.pageCount})',
          errorText: _errorText,
          border: const OutlineInputBorder(),
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Đi tới'),
        ),
      ],
    );
  }
}
