import 'package:flutter/material.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/usecases/login_usecase.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../data/repositories/auth_repository_impl.dart';

class AuthController extends ChangeNotifier {
  final LoginUseCase _loginUseCase;
  final AuthRepository _repository;

  bool _isLoading = false;
  String? _errorMessage;
  String? _passwordHelperError;
  UserEntity? _currentUser;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get passwordHelperError => _passwordHelperError;
  UserEntity? get currentUser => _currentUser;

  AuthController({
    LoginUseCase? loginUseCase,
    AuthRepository? repository,
  })  : _repository = repository ?? AuthRepositoryImpl(),
        _loginUseCase = loginUseCase ?? LoginUseCase(repository ?? AuthRepositoryImpl());

  void clearErrors() {
    _errorMessage = null;
    _passwordHelperError = null;
    notifyListeners();
  }

  Future<UserEntity?> checkSavedSession() async {
    _currentUser = await _repository.getSavedUser();
    notifyListeners();
    return _currentUser;
  }

  Future<bool> login(String username, String password) async {
    _errorMessage = null;
    _passwordHelperError = null;

    if (username.trim().isEmpty) {
      _errorMessage = 'Vui lòng nhập tên đăng nhập hoặc email.';
      notifyListeners();
      return false;
    }

    if (password.isEmpty) {
      _errorMessage = 'Vui lòng nhập mật khẩu.';
      _passwordHelperError = 'Mật khẩu tối thiểu 8 ký tự';
      notifyListeners();
      return false;
    }

    if (password.length < 8) {
      _errorMessage = 'Mật khẩu không hợp lệ.';
      _passwordHelperError = 'Mật khẩu tối thiểu 8 ký tự';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    notifyListeners();

    try {
      _currentUser = await _loginUseCase.execute(username, password);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      if (_errorMessage!.contains('mật khẩu') && password.length < 8) {
        _passwordHelperError = 'Mật khẩu tối thiểu 8 ký tự';
      }
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _repository.logout();
    _currentUser = null;
    notifyListeners();
  }
}
