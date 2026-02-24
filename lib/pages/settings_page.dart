import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:mtg_stats/core/app_theme.dart';
import 'package:mtg_stats/core/ui_feedback.dart';
import 'package:mtg_stats/pages/home_page.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mtg_stats/providers/service_providers.dart';
import 'package:mtg_stats/services/api_config.dart';
import 'package:mtg_stats/services/health_service.dart';

/// Настройки: URL бэкенда, вход, экспорт/импорт.
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  late TextEditingController _urlController;
  late TextEditingController _tokenController;
  late TextEditingController _timezoneController;
  late TextEditingController _loginNameController;
  late TextEditingController _loginPasswordController;
  bool _saving = false;
  bool _loggingIn = false;
  bool _exporting = false;
  bool _importing = false;
  bool _clearingGames = false;
  bool _checkingHealth = false;
  bool _loadingTimezone = false;
  bool _savingTimezone = false;
  int? _timezoneOffsetMinutes;
  HealthResult? _healthResult;
  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: ApiConfig.baseUrl);
    _tokenController = TextEditingController(text: ApiConfig.apiToken);
    _timezoneController = TextEditingController();
    _loginNameController = TextEditingController();
    _loginPasswordController = TextEditingController();
    if (ApiConfig.isAdmin) {
      _loadTimezoneSettings();
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    _tokenController.dispose();
    _timezoneController.dispose();
    _loginNameController.dispose();
    _loginPasswordController.dispose();
    super.dispose();
  }

  void _showSnack(SnackBar snackBar) {
    if (!mounted) return;
    UiFeedback.showRawSnack(context, snackBar);
  }

  Future<void> _login() async {
    final name = _loginNameController.text.trim();
    final password = _loginPasswordController.text;
    if (name.isEmpty || password.isEmpty) {
      _showSnack(
        const SnackBar(
          content: Text('Введите имя и пароль'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    setState(() => _loggingIn = true);
    try {
      final result = await ref.read(authServiceProvider).login(name, password);
      await ApiConfig.setJwt(
        result.token,
        userId: result.userId,
        userName: result.userName,
        isAdmin: result.isAdmin,
      );
      if (mounted) {
        setState(() => _loggingIn = false);
        if (result.isAdmin) {
          _loadTimezoneSettings();
        }
        _loginPasswordController.clear();
        _showSnack(
          SnackBar(
            content: Text(
              result.isAdmin
                  ? 'Вход выполнен: ${result.userName} (админ)'
                  : 'Вход выполнен: ${result.userName}',
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomePage()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loggingIn = false);
        _showSnack(
          SnackBar(
            content: Text('Ошибка входа: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _checkHealth() async {
    setState(() {
      _checkingHealth = true;
      _healthResult = null;
    });
    try {
      final result = await ref.read(healthServiceProvider).check();
      if (mounted) {
        setState(() {
          _checkingHealth = false;
          _healthResult = result;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _checkingHealth = false;
          _healthResult = HealthResult(
            ok: false,
            status: 'error',
            error: e.toString(),
          );
        });
      }
    }
  }

  Future<void> _loadTimezoneSettings() async {
    if (!ApiConfig.isAdmin) return;
    setState(() => _loadingTimezone = true);
    try {
      final settings = await ref.read(appSettingsServiceProvider).getSettings();
      if (!mounted) return;
      setState(() {
        _timezoneController.text = settings.timezone;
        _timezoneOffsetMinutes = settings.timezoneOffsetMinutes;
      });
      ref.invalidate(appSettingsProvider);
    } catch (_) {
      // Не блокируем страницу настроек, если загрузка timezone временно недоступна.
    } finally {
      if (mounted) {
        setState(() => _loadingTimezone = false);
      }
    }
  }

  Future<void> _saveTimezoneSettings() async {
    if (!ApiConfig.isAdmin) return;
    final timezone = _timezoneController.text.trim();
    if (timezone.isEmpty) {
      UiFeedback.showWarning(context, 'Введите timezone, например Europe/Moscow');
      return;
    }
    setState(() => _savingTimezone = true);
    try {
      final settings = await ref
          .read(appSettingsServiceProvider)
          .updateTimezone(timezone);
      if (!mounted) return;
      setState(() {
        _timezoneController.text = settings.timezone;
        _timezoneOffsetMinutes = settings.timezoneOffsetMinutes;
      });
      ref.invalidate(appSettingsProvider);
      UiFeedback.showSuccess(
        context,
        'Timezone сохранен: ${settings.timezone} (UTC${_formatOffset(settings.timezoneOffsetMinutes)})',
      );
    } catch (e) {
      if (mounted) {
        UiFeedback.showError(context, 'Не удалось сохранить timezone: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _savingTimezone = false);
      }
    }
  }

  String _formatOffset(int minutes) {
    final sign = minutes >= 0 ? '+' : '-';
    final abs = minutes.abs();
    final h = abs ~/ 60;
    final m = abs % 60;
    return '$sign${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  Future<void> _logout() async {
    await ApiConfig.clearJwt();
    if (mounted) {
      _showSnack(
        const SnackBar(
          content: Text('Вы вышли из учётной записи'),
          backgroundColor: Colors.grey,
        ),
      );
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomePage()),
        (route) => false,
      );
    }
  }

  Future<void> _save() async {
    final url = _urlController.text.trim();
    final token = _tokenController.text.trim();
    setState(() => _saving = true);
    try {
      await ApiConfig.setBaseUrl(url);
      await ApiConfig.setApiToken(token);
      if (mounted) {
        _showSnack(
          SnackBar(
            content: Text(
              url.isEmpty
                  ? 'Используется сервер по умолчанию'
                  : 'Настройки сохранены',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnack(
          SnackBar(
            content: Text('Ошибка: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _resetToDefault() {
    _urlController.text = ApiConfig.defaultBaseUrl;
    _tokenController.text = '';
  }

  Future<bool> _showConfirmationDialog({
    required String title,
    required String message,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text(
                'Продолжить',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  Future<void> _exportAll() async {
    final result = await showDialog<_ExportResult>(
      context: context,
      builder: (context) => const _ExportDialog(),
    );
    if (result == null || !mounted) return;
    final includePasswords = result.includePasswords;

    final location = await getSaveLocation(
      suggestedName: 'mtg_stats_export.json.gz',
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'GZIP архивы',
          extensions: ['gz'],
          mimeTypes: ['application/gzip', 'application/x-gzip'],
        ),
      ],
    );
    if (location == null || !mounted) return;

    setState(() => _exporting = true);
    try {
      final maintenanceService = ref.read(maintenanceServiceProvider);
      final bytes = await maintenanceService.downloadBackup(
        includePasswords: includePasswords,
      );
      final file = XFile.fromData(
        Uint8List.fromList(bytes),
        name: 'mtg_stats_export.json.gz',
        mimeType: 'application/gzip',
      );
      await file.saveTo(location.path);
      if (mounted) {
        _showSnack(
          const SnackBar(
            content: Text('Экспорт данных выполнен успешно'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnack(
          SnackBar(
            content: Text('Не удалось экспортировать данные: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _exporting = false);
      }
    }
  }

  Future<void> _importAll() async {
    final confirmed = await _showConfirmationDialog(
      title: 'Импорт всех данных',
      message: 'Будет выполнен импорт архива с данными.\n'
          'Все текущие пользователи, колоды, игры и изображения будут ПОЛНОСТЬЮ ЗАМЕНЕНЫ содержимым архива.\n\n'
          'Это необратимая операция. Продолжить?',
    );
    if (!confirmed || !mounted) return;

    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'GZIP архивы',
          extensions: ['gz'],
          mimeTypes: ['application/gzip', 'application/x-gzip'],
        ),
      ],
    );
    if (file == null || !mounted) return;

    setState(() => _importing = true);
    try {
      final maintenanceService = ref.read(maintenanceServiceProvider);
      final bytes = await file.readAsBytes();
      await maintenanceService.importBackupArchive(bytes);
      if (mounted) {
        _showSnack(
          const SnackBar(
            content: Text('Импорт данных выполнен успешно'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnack(
          SnackBar(
            content: Text('Не удалось импортировать данные: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _importing = false);
      }
    }
  }

  Widget _buildLoginSection() {
    if (ApiConfig.isLoggedIn) {
      return Card(
        color: Colors.green[50],
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.person, color: Colors.green[800]),
                  const SizedBox(width: 8),
                  Text(
                    'Вы вошли как ${ApiConfig.currentUserName}',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.green[900],
                    ),
                  ),
                  if (ApiConfig.isAdmin) ...[
                    const SizedBox(width: 8),
                    Chip(
                      label:
                          const Text('Админ', style: TextStyle(fontSize: 12)),
                      backgroundColor: Colors.amber[100],
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () =>
                    Navigator.pushNamed(context, '/settings/change-password'),
                icon: const Icon(Icons.lock, size: 18),
                label: const Text('Сменить пароль'),
              ),
              if (ApiConfig.isAdmin) const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/users'),
                icon: const Icon(Icons.people, size: 18),
                label: const Text('Управление пользователями'),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout, size: 18),
                label: const Text('Выйти'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red[700],
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Вход в учётную запись',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.blueGrey[800],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Войдите под учётной записью администратора для доступа ко всем настройкам',
              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _loginNameController,
              decoration: InputDecoration(
                labelText: 'Имя',
                hintText: 'Имя пользователя',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _loginPasswordController,
              decoration: InputDecoration(
                labelText: 'Пароль',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              obscureText: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _login(),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _loggingIn ? null : _login,
              icon: _loggingIn
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.login, size: 18),
              label: Text(_loggingIn ? 'Вход...' : 'Войти'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueGrey[800],
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _clearGames() async {
    final confirmed = await _showConfirmationDialog(
      title: 'Очистка игр и ходов',
      message:
          'Все игры и их ходы будут безвозвратно удалены из базы данных.\n\n'
          'Вы уверены, что хотите продолжить?',
    );
    if (!confirmed || !mounted) return;

    setState(() => _clearingGames = true);
    try {
      await ref.read(maintenanceServiceProvider).clearGames();
      if (mounted) {
        _showSnack(
          const SnackBar(
            content: Text('Таблицы игр и ходов успешно очищены'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnack(
          SnackBar(
            content: Text('Не удалось очистить игры: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _clearingGames = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Настройки', style: AppTheme.appBarTitle),
        backgroundColor: AppTheme.appBarBackground,
        foregroundColor: AppTheme.appBarForeground,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildLoginSection(),
            if (ApiConfig.isAdmin) ...[
              const SizedBox(height: 24),
              Text(
                'URL сервера бэкенда',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.blueGrey[800],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Для локального сервера: http://localhost:8080',
                style: TextStyle(fontSize: 13, color: Colors.grey[700]),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _urlController,
                decoration: InputDecoration(
                  hintText: 'https://... или http://localhost:PORT',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _save(),
              ),
              const SizedBox(height: 12),
              Card(
                color: Colors.blueGrey[50],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blueGrey[700]),
                          const SizedBox(width: 8),
                          Text(
                            'Как подключиться к локальному серверу',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.blueGrey[800],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'При сборке можно задать URL через dart-define:\n'
                        'flutter run --dart-define=BASE_URL=http://localhost:8080',
                        style: TextStyle(
                            fontSize: 13, color: Colors.blueGrey[800]),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _checkingHealth ? null : _checkHealth,
                    icon: _checkingHealth
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.health_and_safety, size: 18),
                    label: Text(
                      _checkingHealth ? 'Проверка...' : 'Проверить подключение',
                    ),
                  ),
                ],
              ),
              if (_healthResult != null) ...[
                const SizedBox(height: 12),
                Card(
                  color: _healthResult!.ok ? Colors.green[50] : Colors.red[50],
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _healthResult!.ok
                                  ? Icons.check_circle
                                  : Icons.error,
                              color: _healthResult!.ok
                                  ? Colors.green[700]
                                  : Colors.red[700],
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _healthResult!.ok
                                  ? 'Сервер доступен'
                                  : 'Ошибка подключения',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: _healthResult!.ok
                                    ? Colors.green[800]
                                    : Colors.red[800],
                              ),
                            ),
                          ],
                        ),
                        if (_healthResult!.database != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'База данных: ${_healthResult!.database}',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[700],
                              ),
                            ),
                          ),
                        if (_healthResult!.error != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              _healthResult!.error!,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.red[800],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Text(
                'Часовой пояс приложения',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.blueGrey[800],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Все даты в интерфейсе будут отображаться в этом timezone.',
                style: TextStyle(fontSize: 13, color: Colors.grey[700]),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _timezoneController,
                decoration: InputDecoration(
                  hintText: 'Например: Europe/Moscow',
                  suffixIcon: _loadingTimezone
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _saveTimezoneSettings(),
              ),
              if (_timezoneOffsetMinutes != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Текущий сдвиг: UTC${_formatOffset(_timezoneOffsetMinutes!)}',
                  style: TextStyle(fontSize: 13, color: Colors.blueGrey[700]),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _savingTimezone ? null : _saveTimezoneSettings,
                    icon: _savingTimezone
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.schedule, size: 18),
                    label: Text(
                      _savingTimezone ? 'Сохранение...' : 'Сохранить timezone',
                    ),
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: _loadingTimezone ? null : _loadTimezoneSettings,
                    child: const Text('Обновить'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'API токен',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.blueGrey[800],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Бэкенд защищён API_TOKEN, укажите его здесь',
                style: TextStyle(fontSize: 13, color: Colors.grey[700]),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _tokenController,
                decoration: InputDecoration(
                  hintText: 'Секретный токен или пусто',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                obscureText: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _save(),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save, size: 20),
                      label: Text(_saving ? 'Сохранение...' : 'Сохранить'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueGrey[800],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: _resetToDefault,
                    child: const Text('По умолчанию'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Импорт / экспорт и очистка данных',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Операции ниже могут затрагивать все данные приложения. '
                        'Перед импортом рекомендуется сделать экспорт.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed:
                              (_saving || _exporting) ? null : _exportAll,
                          icon: _exporting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                )
                              : const Icon(Icons.file_download),
                          label: Text(
                            _exporting
                                ? 'Экспортируется...'
                                : 'Экспортировать все данные',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.indigo[700],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed:
                              (_saving || _importing) ? null : _importAll,
                          icon: _importing
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                )
                              : const Icon(Icons.file_upload),
                          label: Text(
                            _importing
                                ? 'Импортируется...'
                                : 'Импортировать все данные',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange[700],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed:
                              (_saving || _clearingGames) ? null : _clearGames,
                          icon: _clearingGames
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                )
                              : const Icon(Icons.delete_forever),
                          label: Text(
                            _clearingGames
                                ? 'Очищается...'
                                : 'Очистить игры и ходы',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red[700],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ExportResult {
  final bool includePasswords;
  const _ExportResult({required this.includePasswords});
}

class _ExportDialog extends StatefulWidget {
  const _ExportDialog();

  @override
  State<_ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends State<_ExportDialog> {
  bool _includePasswords = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Экспорт всех данных'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Будет выполнен экспорт (пользователи, колоды, игры, изображения).',
          ),
          const SizedBox(height: 16),
          CheckboxListTile(
            title: const Text('Включить пароли', style: TextStyle(fontSize: 14)),
            subtitle: const Text(
              'Для полного восстановления на другом сервере',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            value: _includePasswords,
            onChanged: (v) => setState(() => _includePasswords = v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Отмена'),
        ),
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(_ExportResult(includePasswords: _includePasswords)),
          child: const Text('Экспортировать'),
        ),
      ],
    );
  }
}
