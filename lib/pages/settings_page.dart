import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:mtg_stats/core/app_theme.dart';
import 'package:mtg_stats/services/api_config.dart';
import 'package:mtg_stats/services/maintenance_service.dart';

/// Настройки: URL бэкенда.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late TextEditingController _urlController;
  bool _saving = false;
  final MaintenanceService _maintenanceService = MaintenanceService();
  bool _exporting = false;
  bool _importing = false;
  bool _clearingGames = false;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: ApiConfig.baseUrl);
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final url = _urlController.text.trim();
    setState(() => _saving = true);
    try {
      await ApiConfig.setBaseUrl(url);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              url.isEmpty
                  ? 'Используется сервер по умолчанию'
                  : 'Сервер сохранён: $url',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
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
    final confirmed = await _showConfirmationDialog(
      title: 'Экспорт всех данных',
      message:
          'Будет выполнен экспорт всех данных (пользователи, колоды, игры, изображения).'
          '\n\nВы уверены, что хотите продолжить?',
    );
    if (!confirmed || !mounted) return;

    final location = await getSaveLocation(
      suggestedName: 'mtg_stats_export.json.gz',
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'GZIP архивы',
          extensions: ['gz'],
        ),
      ],
    );
    if (location == null || !mounted) return;

    setState(() => _exporting = true);
    try {
      final bytes = await _maintenanceService.downloadBackup();
      final file = XFile.fromData(
        Uint8List.fromList(bytes),
        name: 'mtg_stats_export.json.gz',
        mimeType: 'application/gzip',
      );
      await file.saveTo(location.path);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Экспорт данных выполнен успешно'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
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
      message:
          'Будет выполнен импорт архива с данными.\n'
          'Все текущие пользователи, колоды, игры и изображения будут ПОЛНОСТЬЮ ЗАМЕНЕНЫ содержимым архива.\n\n'
          'Это необратимая операция. Продолжить?',
    );
    if (!confirmed || !mounted) return;

    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'GZIP архивы',
          extensions: ['gz'],
        ),
      ],
    );
    if (file == null || !mounted) return;

    setState(() => _importing = true);
    try {
      final bytes = await file.readAsBytes();
      await _maintenanceService.importBackupArchive(bytes);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Импорт данных выполнен успешно'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        print('Не удалось импортировать данные: $e');
        ScaffoldMessenger.of(context).showSnackBar(
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
      await _maintenanceService.clearGames();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Таблицы игр и ходов успешно очищены'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
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
                        onPressed: (_saving || _exporting) ? null : _exportAll,
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
                        onPressed: (_saving || _importing) ? null : _importAll,
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
                      style: TextStyle(fontSize: 13, color: Colors.blueGrey[800]),
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
