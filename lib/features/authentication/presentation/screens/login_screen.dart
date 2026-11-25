import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../shared/widgets/brand_logo.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../controller/auth_controller.dart';
import 'account_screen.dart';
import '../widgets/login_error_banner.dart';
import '../../../home/presentation/screens/home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _controller = AuthController();
  final _usernameController = TextEditingController(text: 'an.nguyen');
  final _passwordController = TextEditingController(text: 'MatKhau@123');

  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerUpdate);
  }

  void _onControllerUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerUpdate);
    _controller.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final success = await _controller.login(
      _usernameController.text,
      _passwordController.text,
    );

    if (success && mounted && _controller.currentUser != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => HomeScreen(user: _controller.currentUser!),
        ),
      );
    }
  }

  Future<void> _openAccount(AccountAction action) async {
    final message = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => AccountScreen(action: action)),
    );
    if (mounted && message != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  void _fillAccount(String username, String password) {
    _usernameController.text = username;
    _passwordController.text = password;
    _controller.clearErrors();
  }

  @override
  Widget build(BuildContext context) {
    final hasError = _controller.errorMessage != null;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Brand Logo
              const BrandLogo(iconSize: 20, fontSize: 18),
              const SizedBox(height: 32),

              // Title "Đăng nhập"
              const Text(
                AppStrings.loginTitle,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 24),

              // Error Alert Banner (Image 1 - Login error)
              if (hasError) ...[
                LoginErrorBanner(errorMessage: _controller.errorMessage!),
                const SizedBox(height: 20),
              ],

              // Email / Username Label
              const Text(
                AppStrings.emailOrUsername,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),

              // Email / Username Input
              TextFormField(
                controller: _usernameController,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: AppStrings.emailPlaceholder,
                  hintStyle: const TextStyle(
                    color: AppColors.textHint,
                    fontSize: 14,
                  ),
                  prefixIcon: const Icon(
                    Icons.mail_outline_rounded,
                    color: AppColors.textHint,
                    size: 20,
                  ),
                  filled: true,
                  fillColor: hasError
                      ? const Color(0xFFFFFBFB)
                      : AppColors.surfaceMuted,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: hasError ? AppColors.error : AppColors.border,
                      width: 1.2,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: hasError ? AppColors.error : AppColors.primary,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Password Label
              const Text(
                AppStrings.password,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),

              // Password Input
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: '••••••••',
                  hintStyle: const TextStyle(
                    color: AppColors.textHint,
                    fontSize: 14,
                  ),
                  prefixIcon: const Icon(
                    Icons.lock_outline_rounded,
                    color: AppColors.textHint,
                    size: 20,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: AppColors.textHint,
                      size: 20,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                  filled: true,
                  fillColor: hasError
                      ? const Color(0xFFFFFBFB)
                      : AppColors.surfaceMuted,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: hasError ? AppColors.error : AppColors.border,
                      width: 1.2,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: hasError ? AppColors.error : AppColors.primary,
                      width: 1.5,
                    ),
                  ),
                ),
              ),

              // Password helper error
              if (_controller.passwordHelperError != null) ...[
                const SizedBox(height: 6),
                Text(
                  _controller.passwordHelperError!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.error,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],

              // Forgot password link
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => _openAccount(AccountAction.forgot),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: const Text(
                    AppStrings.forgotPassword,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Login Button (Orange solid)
              CustomButton(
                text: AppStrings.loginButton,
                onPressed: _handleLogin,
                isLoading: _controller.isLoading,
              ),
              const SizedBox(height: 24),

              // Divider "hoặc"
              Row(
                children: [
                  const Expanded(
                    child: Divider(color: AppColors.border, thickness: 1),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      AppStrings.orDivider,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ),
                  const Expanded(
                    child: Divider(color: AppColors.border, thickness: 1),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Google Login Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Tính năng Google OAuth đang được cập nhật.',
                        ),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.border, width: 1.2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    backgroundColor: Colors.white,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        alignment: Alignment.center,
                        child: const Text(
                          'G',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF4285F4),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        AppStrings.googleLogin,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF334155),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              TextButton(
                onPressed: () => _openAccount(AccountAction.register),
                child: const Text('Đăng ký tài khoản'),
              ),
              TextButton(
                onPressed: () => _openAccount(AccountAction.verify),
                child: const Text('Xác thực email tài khoản'),
              ),
              const SizedBox(height: 36),

              // Test credentials panel
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.vpn_key_rounded,
                          size: 16,
                          color: AppColors.textMuted,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Tài khoản kiểm thử nhanh:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        ActionChip(
                          avatar: const Icon(
                            Icons.check_circle,
                            size: 16,
                            color: Colors.green,
                          ),
                          label: const Text('an.nguyen (VĐV/Runner)'),
                          backgroundColor: Colors.white,
                          onPressed: () =>
                              _fillAccount('an.nguyen', 'MatKhau@123'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
