import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/errors/app_exceptions.dart';
import '../../../authentication/domain/entities/user_entity.dart';
import '../../domain/runner_models.dart';
import '../../domain/runner_repository.dart';

class RunnerProfileScreen extends StatefulWidget {
  final UserEntity user;
  final RunnerRepository repository;

  const RunnerProfileScreen({
    super.key,
    required this.user,
    required this.repository,
  });

  @override
  State<RunnerProfileScreen> createState() => _RunnerProfileScreenState();
}

class _RunnerProfileScreenState extends State<RunnerProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _idNumberController = TextEditingController();

  RunnerProfile? profile;
  DateTime? dateOfBirth;
  int gender = 0;
  bool loading = true;
  bool saving = false;
  String? error;
  String? success;

  Map<String, dynamic> get fields =>
      profile?.fields ?? const <String, dynamic>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _idNumberController.dispose();
    super.dispose();
  }

  int _genderCode(dynamic value) {
    if (value is num) return value.toInt().clamp(0, 2).toInt();
    return switch (value?.toString().toLowerCase()) {
      'male' || 'nam' => 1,
      'female' || 'nữ' || 'nu' => 2,
      _ => 0,
    };
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
      success = null;
    });
    try {
      final loaded = await widget.repository.profile();
      if (!mounted) return;
      setState(() {
        profile = loaded;
        _nameController.text = loaded.fields['fullName']?.toString() ?? '';
        _phoneController.text = loaded.fields['phone']?.toString() ?? '';
        _idNumberController.text = loaded.fields['idNumber']?.toString() ?? '';
        dateOfBirth = DateTime.tryParse(
          loaded.fields['dateOfBirth']?.toString() ?? '',
        );
        gender = _genderCode(loaded.fields['gender']);
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = _message(e);
      });
    }
  }

  String _message(Object exception) => exception is AppException
      ? exception.message
      : exception.toString().replaceFirst('Exception: ', '');

  Future<void> _selectDate() async {
    final today = DateTime.now();
    final firstDate = DateTime(today.year - 100, today.month, today.day);
    final lastDate = DateTime(today.year - 5, today.month, today.day);
    final currentDate = dateOfBirth ??
        DateTime(today.year - 25, today.month, today.day);
    final initialDate = currentDate.isBefore(firstDate)
        ? firstDate
        : currentDate.isAfter(lastDate)
        ? lastDate
        : currentDate;
    final selected = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: 'Chọn ngày sinh',
      cancelText: 'Hủy',
      confirmText: 'Chọn',
    );
    if (selected != null) {
      setState(() {
        dateOfBirth = selected;
        success = null;
      });
    }
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      saving = true;
      error = null;
      success = null;
    });

    try {
      final body = <String, dynamic>{
        'fullName': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'dateOfBirth': dateOfBirth == null
            ? null
            : '${dateOfBirth!.year.toString().padLeft(4, '0')}-'
                  '${dateOfBirth!.month.toString().padLeft(2, '0')}-'
                  '${dateOfBirth!.day.toString().padLeft(2, '0')}',
        'gender': gender,
        'avatarUrl': fields['avatarUrl'],
        // Empty string tells the API that the runner cleared this field.
        'idNumber': _idNumberController.text.trim(),
      };
      final updated = await widget.repository.updateProfile(body);
      if (!mounted) return;
      setState(() {
        profile = updated;
        _nameController.text = updated.fields['fullName']?.toString() ?? '';
        _phoneController.text = updated.fields['phone']?.toString() ?? '';
        _idNumberController.text = updated.fields['idNumber']?.toString() ?? '';
        dateOfBirth = DateTime.tryParse(
          updated.fields['dateOfBirth']?.toString() ?? '',
        );
        gender = _genderCode(updated.fields['gender']);
        saving = false;
        success = 'Đã lưu hồ sơ runner.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        saving = false;
        error = _message(e);
      });
    }
  }

  String _dateLabel(DateTime? value) {
    if (value == null) return 'Chưa cập nhật';
    return '${value.day.toString().padLeft(2, '0')}/'
        '${value.month.toString().padLeft(2, '0')}/'
        '${value.year}';
  }

  int get _completedFields => [
    _nameController.text.trim().isNotEmpty,
    _phoneController.text.trim().isNotEmpty,
    dateOfBirth != null,
    gender != 0,
    _idNumberController.text.trim().isNotEmpty,
  ].where((complete) => complete).length;

  InputDecoration _decoration(String label, {Widget? suffixIcon}) =>
      InputDecoration(
        labelText: label,
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: AppColors.surfaceMuted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());

    if (profile == null) {
      return Center(
        child: _MessageCard(
          message: error ?? 'Chưa tải được hồ sơ runner.',
          onRetry: _load,
        ),
      );
    }

    final name = _nameController.text.trim().isEmpty
        ? widget.user.username
        : _nameController.text.trim();
    final email = fields['email']?.toString() ?? widget.user.email ?? '';
    final progress = _completedFields / 5;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hồ sơ runner',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Thông tin dùng cho vé và các giải bạn tham gia.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                onPressed: _load,
                tooltip: 'Tải lại hồ sơ',
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _ProfileHeader(
            name: name,
            username: fields['username']?.toString() ?? widget.user.username,
            email: email,
            completedFields: _completedFields,
            progress: progress,
          ),
          const SizedBox(height: 18),
          if (error != null) ...[
            _MessageCard(message: error!, isError: true),
            const SizedBox(height: 12),
          ],
          if (success != null) ...[
            _MessageCard(message: success!, isSuccess: true),
            const SizedBox(height: 12),
          ],
          Form(
            key: _formKey,
            child: Column(
              children: [
                _SectionCard(
                  icon: Icons.person_outline,
                  title: 'Thông tin cá nhân',
                  subtitle: 'Tên, liên hệ và giấy tờ của bạn',
                  children: [
                    TextFormField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      decoration: _decoration('Họ và tên'),
                      validator: (value) {
                        if (value == null || value.trim().length < 2) {
                          return 'Nhập họ tên từ 2 ký tự trở lên.';
                        }
                        if (value.trim().length > 100) {
                          return 'Họ tên tối đa 100 ký tự.';
                        }
                        return null;
                      },
                      onChanged: (_) => setState(() => success = null),
                    ),
                    const SizedBox(height: 14),
                    _ReadOnlyField(
                      label: 'Email tài khoản',
                      value: email.isEmpty ? 'Chưa cập nhật' : email,
                      icon: Icons.mail_outline,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      decoration: _decoration(
                        'Số điện thoại',
                        suffixIcon: const Icon(Icons.phone_outlined),
                      ),
                      validator: (value) {
                        final phone = value?.trim() ?? '';
                        if (phone.isEmpty) return null;
                        if (!RegExp(r'^(0|\+84)(3|5|7|8|9)\d{8}$')
                            .hasMatch(phone)) {
                          return 'Nhập số di động Việt Nam hợp lệ.';
                        }
                        return null;
                      },
                      onChanged: (_) => setState(() => success = null),
                    ),
                    const SizedBox(height: 14),
                    InkWell(
                      onTap: _selectDate,
                      borderRadius: BorderRadius.circular(14),
                      child: InputDecorator(
                        decoration: _decoration(
                          'Ngày sinh',
                          suffixIcon: const Icon(Icons.calendar_month_outlined),
                        ),
                        child: Text(
                          _dateLabel(dateOfBirth),
                          style: TextStyle(
                            color: dateOfBirth == null
                                ? AppColors.textMuted
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                    if (dateOfBirth != null)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () => setState(() {
                            dateOfBirth = null;
                            success = null;
                          }),
                          icon: const Icon(Icons.close, size: 16),
                          label: const Text('Xóa ngày sinh'),
                        ),
                      ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      initialValue: gender,
                      decoration: _decoration('Giới tính'),
                      items: const [
                        DropdownMenuItem(value: 0, child: Text('Chưa chọn')),
                        DropdownMenuItem(value: 1, child: Text('Nam')),
                        DropdownMenuItem(value: 2, child: Text('Nữ')),
                      ],
                      onChanged: (value) => setState(() {
                        gender = value ?? 0;
                        success = null;
                      }),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _idNumberController,
                      textCapitalization: TextCapitalization.characters,
                      textInputAction: TextInputAction.done,
                      decoration: _decoration(
                        'CCCD / CMND / hộ chiếu',
                        suffixIcon: const Icon(Icons.badge_outlined),
                      ),
                      validator: (value) {
                        final id = value?.trim() ?? '';
                        if (id.isEmpty ||
                            RegExp(r'^\d{9}$|^\d{12}$').hasMatch(id) ||
                            RegExp(r'^[A-Za-z][A-Za-z0-9]{5,11}$')
                                .hasMatch(id)) {
                          return null;
                        }
                        return 'Nhập CMND 9 số, CCCD 12 số hoặc hộ chiếu hợp lệ.';
                      },
                      onChanged: (_) => setState(() => success = null),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                _SectionCard(
                  icon: Icons.lock_outline,
                  title: 'Thông tin tài khoản',
                  subtitle: 'Thông tin đăng nhập không thể sửa tại đây',
                  children: [
                    _ReadOnlyField(
                      label: 'Tên đăng nhập',
                      value: fields['username']?.toString() ?? widget.user.username,
                      icon: Icons.alternate_email,
                    ),
                    const SizedBox(height: 12),
                    _ReadOnlyField(
                      label: 'Vai trò',
                      value: 'Vận động viên',
                      icon: Icons.directions_run,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton.icon(
                    onPressed: saving ? null : _save,
                    icon: saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(saving ? 'Đang lưu…' : 'Lưu hồ sơ'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Thông tin cá nhân sẽ được điền sẵn khi bạn đăng ký giải.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final String name;
  final String username;
  final String email;
  final int completedFields;
  final double progress;

  const _ProfileHeader({
    required this.name,
    required this.username,
    required this.email,
    required this.completedFields,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFFFF713D), Color(0xFFE94712)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(22),
      boxShadow: [
        BoxShadow(
          color: AppColors.primary.withValues(alpha: 0.2),
          blurRadius: 22,
          offset: const Offset(0, 10),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.55)),
              ),
              child: const Icon(
                Icons.directions_run,
                color: Colors.white,
                size: 29,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '@$username',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.84),
                      fontSize: 13,
                    ),
                  ),
                  if (email.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.84),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Độ hoàn thiện hồ sơ',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              '$completedFields/5',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 7,
            backgroundColor: Colors.white.withValues(alpha: 0.28),
            color: Colors.white,
          ),
        ),
      ],
    ),
  );
}

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Widget> children;

  const _SectionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 14),
    elevation: 0,
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: const BorderSide(color: AppColors.border),
    ),
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.primaryDark, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ...children,
        ],
      ),
    ),
  );
}

class _ReadOnlyField extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _ReadOnlyField({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) => InputDecorator(
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: const Color(0xFFF1F5F9),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    ),
    child: Text(
      value,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(color: AppColors.textSecondary),
    ),
  );
}

class _MessageCard extends StatelessWidget {
  final String message;
  final bool isError;
  final bool isSuccess;
  final VoidCallback? onRetry;

  const _MessageCard({
    required this.message,
    this.isError = false,
    this.isSuccess = false,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final color = isError
        ? AppColors.error
        : isSuccess
        ? AppColors.success
        : AppColors.textSecondary;
    final background = isError
        ? AppColors.errorBg
        : isSuccess
        ? AppColors.successBg
        : Colors.white;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isError
              ? AppColors.errorBorder
              : isSuccess
              ? AppColors.success.withValues(alpha: 0.25)
              : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isError
                ? Icons.error_outline
                : isSuccess
                ? Icons.check_circle_outline
                : Icons.info_outline,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: TextStyle(color: color)),
          ),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: const Text('Thử lại')),
        ],
      ),
    );
  }
}
