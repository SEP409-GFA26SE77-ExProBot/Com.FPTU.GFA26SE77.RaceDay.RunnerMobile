import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_client.dart';

enum AccountAction { register, verify, forgot, reset, change }

class AccountScreen extends StatefulWidget {
  final AccountAction action;
  final String? token;
  final ApiClient? client;
  const AccountScreen({
    super.key,
    required this.action,
    this.token,
    this.client,
  });

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final form = GlobalKey<FormState>();
  final email = TextEditingController();
  final username = TextEditingController();
  final name = TextEditingController();
  final phone = TextEditingController();
  final password = TextEditingController();
  final confirm = TextEditingController();
  final current = TextEditingController();
  final otp = TextEditingController();
  late AccountAction action = widget.action;
  late final ApiClient client = widget.client ?? ApiClient();
  bool busy = false;
  String? error, notice;
  int resendAfter = 0;

  String get title => switch (action) {
    AccountAction.register => 'Tạo tài khoản',
    AccountAction.verify => 'Xác thực email',
    AccountAction.forgot => 'Quên mật khẩu',
    AccountAction.reset => 'Đặt lại mật khẩu',
    AccountAction.change => 'Đổi mật khẩu',
  };

  @override
  void dispose() {
    for (final c in [
      email,
      username,
      name,
      phone,
      password,
      confirm,
      current,
      otp,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> submit() async {
    if (busy || !form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
      notice = null;
    });
    try {
      final address = email.text.trim();
      switch (action) {
        case AccountAction.register:
          await client.post(
            ApiEndpoints.register,
            body: {
              'email': address,
              'username': username.text.trim(),
              'fullName': name.text.trim(),
              'password': password.text,
              'phone': phone.text.trim().isEmpty ? null : phone.text.trim(),
            },
          );
          if (!mounted) return;
          setState(() {
            action = AccountAction.verify;
            notice = 'Đã gửi mã OTP đến email của bạn.';
          });
          password.clear();
          confirm.clear();
        case AccountAction.verify:
          await client.post(
            ApiEndpoints.verifyEmail,
            body: {'email': address, 'otp': otp.text.trim()},
          );
          if (!mounted) return;
          Navigator.pop(context, 'Đã xác thực email. Bạn có thể đăng nhập.');
        case AccountAction.forgot:
          await client.post(
            ApiEndpoints.forgotPassword,
            body: {'email': address},
          );
          if (!mounted) return;
          setState(() {
            action = AccountAction.reset;
            notice =
                'Nếu email hợp lệ, mã đặt lại mật khẩu sẽ được gửi đến hộp thư.';
          });
        case AccountAction.reset:
          await client.post(
            ApiEndpoints.resetPassword,
            body: {
              'email': address,
              'otp': otp.text.trim(),
              'newPassword': password.text,
            },
          );
          if (!mounted) return;
          Navigator.pop(context, 'Đã đặt lại mật khẩu. Vui lòng đăng nhập.');
        case AccountAction.change:
          await client.post(
            ApiEndpoints.changePassword,
            token: widget.token,
            body: {
              'currentPassword': current.text,
              'newPassword': password.text,
            },
          );
          if (!mounted) return;
          Navigator.pop(context, 'Đã đổi mật khẩu.');
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget field(
    TextEditingController c,
    String label, {
    bool secret = false,
    TextInputType? keyboard,
    int? max,
    String? Function(String?)? validator,
    List<TextInputFormatter>? formatters,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: c,
      enabled: !busy,
      obscureText: secret,
      keyboardType: keyboard,
      maxLength: max,
      inputFormatters: formatters,
      autocorrect: !secret,
      enableSuggestions: !secret,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      validator:
          validator ??
          (v) => (v?.trim().isEmpty ?? true) ? 'Vui lòng nhập $label.' : null,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final newPassword = [
      AccountAction.register,
      AccountAction.reset,
      AccountAction.change,
    ].contains(action);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (notice != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(notice!),
                ),
              Form(
                key: form,
                child: Column(
                  children: [
                    if (action != AccountAction.change)
                      field(
                        email,
                        'Email',
                        keyboard: TextInputType.emailAddress,
                        max: 100,
                        validator: (v) =>
                            RegExp(
                              r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                            ).hasMatch(v?.trim() ?? '')
                            ? null
                            : 'Nhập email hợp lệ.',
                      ),
                    if (action == AccountAction.register) ...[
                      field(
                        username,
                        'Tên đăng nhập',
                        max: 50,
                        validator: (v) =>
                            RegExp(
                              r'^[a-zA-Z0-9._-]{3,50}$',
                            ).hasMatch(v?.trim() ?? '')
                            ? null
                            : 'Dùng 3–50 ký tự: chữ, số, dấu chấm, _ hoặc -.',
                      ),
                      field(name, 'Họ và tên', max: 100),
                      field(
                        phone,
                        'Số điện thoại (không bắt buộc)',
                        keyboard: TextInputType.phone,
                        max: 20,
                        validator: (v) =>
                            v!.trim().isEmpty ||
                                RegExp(
                                  r'^(0|\+84)(3|5|7|8|9)\d{8}$',
                                ).hasMatch(v.trim())
                            ? null
                            : 'Nhập số di động Việt Nam hợp lệ.',
                      ),
                    ],
                    if (action == AccountAction.change)
                      field(current, 'Mật khẩu hiện tại', secret: true),
                    if (action == AccountAction.verify ||
                        action == AccountAction.reset)
                      field(
                        otp,
                        'Mã OTP',
                        keyboard: TextInputType.number,
                        max: 6,
                        formatters: [FilteringTextInputFormatter.digitsOnly],
                        validator: (v) => RegExp(r'^\d{6}$').hasMatch(v ?? '')
                            ? null
                            : 'Nhập đủ 6 chữ số OTP.',
                      ),
                    if (newPassword) ...[
                      field(
                        password,
                        'Mật khẩu mới',
                        secret: true,
                        max: 100,
                        validator: (v) => v != null && v.length >= 8
                            ? null
                            : 'Mật khẩu tối thiểu 8 ký tự.',
                      ),
                      field(
                        confirm,
                        'Xác nhận mật khẩu',
                        secret: true,
                        max: 100,
                        validator: (v) => v == password.text
                            ? null
                            : 'Mật khẩu xác nhận không khớp.',
                      ),
                    ],
                  ],
                ),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              FilledButton(
                onPressed: busy ? null : submit,
                child: Text(busy ? 'Đang xử lý…' : title),
              ),
              if (action == AccountAction.verify ||
                  action == AccountAction.reset)
                TextButton(
                  onPressed: busy
                      ? null
                      : () {
                          // Resending only needs a valid email; OTP/new password may be blank.
                          if (!RegExp(
                            r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                          ).hasMatch(email.text.trim())) {
                            setState(
                              () => error = 'Nhập email hợp lệ để gửi lại mã.',
                            );
                          } else {
                            resend();
                          }
                        },
                  child: const Text('Gửi lại mã OTP'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> resend() async {
    if (busy) return;
    if (DateTime.now().millisecondsSinceEpoch < resendAfter) {
      setState(() => error = 'Vui lòng chờ 60 giây trước khi gửi lại mã.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await client.post(
        action == AccountAction.verify
            ? ApiEndpoints.resendOtp
            : ApiEndpoints.forgotPassword,
        body: {'email': email.text.trim()},
      );
      resendAfter = DateTime.now().millisecondsSinceEpoch + 60000;
      if (mounted) {
        setState(
          () => notice = 'Đã yêu cầu gửi lại mã OTP. Vui lòng kiểm tra email.',
        );
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}
