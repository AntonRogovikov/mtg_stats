import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mtg_stats/core/app_theme.dart';
import 'package:mtg_stats/core/ui_feedback.dart';
import 'package:mtg_stats/providers/service_providers.dart';
import 'package:mtg_stats/services/api_config.dart';

/// Экран смены пароля для авторизованного пользователя.
class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  bool _changingPassword = false;

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    final newPass = _newPasswordController.text;
    final confirm = _confirmPasswordController.text;
    if (newPass.isEmpty) {
      UiFeedback.showWarning(context, 'Введите новый пароль');
      return;
    }
    if (newPass != confirm) {
      UiFeedback.showWarning(context, 'Пароли не совпадают');
      return;
    }
    if (newPass.length < 4) {
      UiFeedback.showWarning(context, 'Пароль должен быть не менее 4 символов');
      return;
    }
    final userId = ApiConfig.currentUserId;
    if (userId.isEmpty) {
      UiFeedback.showError(context, 'Ошибка: ID пользователя не найден');
      return;
    }
    setState(() => _changingPassword = true);
    try {
      await ProviderScope.containerOf(context, listen: false)
          .read(userServiceProvider)
          .updateUser(
            userId,
            ApiConfig.currentUserName,
            password: newPass,
          );
      if (mounted) {
        _newPasswordController.clear();
        _confirmPasswordController.clear();
        setState(() => _changingPassword = false);
        UiFeedback.showSuccess(context, 'Пароль успешно изменён');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _changingPassword = false);
        UiFeedback.showError(context, 'Ошибка: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!ApiConfig.isLoggedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
      return const Scaffold(body: SizedBox.shrink());
    }
    return Scaffold(
      appBar: AppBar(
        title: Text('Сменить пароль', style: AppTheme.appBarTitle),
        backgroundColor: AppTheme.appBarBackground,
        foregroundColor: AppTheme.appBarForeground,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Новый пароль',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.blueGrey[800],
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _newPasswordController,
                      decoration: InputDecoration(
                        labelText: 'Новый пароль',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      obscureText: true,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _confirmPasswordController,
                      decoration: InputDecoration(
                        labelText: 'Подтвердите пароль',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _changePassword(),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _changingPassword ? null : _changePassword,
                        icon: _changingPassword
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.lock, size: 18),
                        label: Text(
                          _changingPassword
                              ? 'Сохранение...'
                              : 'Сменить пароль',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueGrey[800],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
