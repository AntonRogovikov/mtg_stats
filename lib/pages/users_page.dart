import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mtg_stats/core/app_theme.dart';
import 'package:mtg_stats/core/ui_feedback.dart';
import 'package:mtg_stats/models/user.dart';
import 'package:mtg_stats/providers/service_providers.dart';
import 'package:mtg_stats/services/api_config.dart';

/// Управление пользователями (только для администраторов).
class UsersPage extends ConsumerStatefulWidget {
  const UsersPage({super.key});

  @override
  ConsumerState<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends ConsumerState<UsersPage> {
  void _showSnack(String message, Color color) {
    if (!mounted) return;
    UiFeedback.showMessage(
      context,
      message: message,
      backgroundColor: color,
    );
  }

  Future<void> _refreshUsers() async {
    ref.invalidate(usersProvider);
    await ref.read(usersProvider.future);
  }

  Future<void> _showCreateDialog() async {
    final nameController = TextEditingController();
    final passwordController = TextEditingController();
    bool isAdmin = false;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Новый пользователь'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Имя',
                      hintText: '2–100 символов',
                    ),
                    autofocus: true,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passwordController,
                    decoration: const InputDecoration(
                      labelText: 'Пароль',
                      hintText: 'Опционально',
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    title: const Text('Администратор'),
                    value: isAdmin,
                    onChanged: (v) => setDialogState(() => isAdmin = v ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Отмена'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Создать'),
              ),
            ],
          );
        },
      ),
    );

    if (result != true || !mounted) return;

    final name = nameController.text.trim();
    if (name.length < 2) {
      _showSnack('Имя от 2 до 100 символов', Colors.orange);
      return;
    }

    try {
      await ref.read(userServiceProvider).createUser(
        name,
        password: passwordController.text.isNotEmpty
            ? passwordController.text
            : null,
        isAdmin: isAdmin,
      );
      if (mounted) {
        _showSnack('Пользователь создан', Colors.green);
        ref.invalidate(usersProvider);
      }
    } catch (e) {
      _showSnack('Ошибка: $e', Colors.red);
    }
  }

  Future<void> _showEditDialog(User user) async {
    final nameController = TextEditingController(text: user.name);
    final passwordController = TextEditingController();
    bool isAdmin = user.isAdmin;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Редактировать пользователя'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Имя',
                      hintText: '2–100 символов',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passwordController,
                    decoration: const InputDecoration(
                      labelText: 'Новый пароль',
                      hintText: 'Оставьте пустым, чтобы не менять',
                    ),
                    obscureText: true,
                  ),
                  if (ApiConfig.isAdmin)
                    CheckboxListTile(
                      title: const Text('Администратор'),
                      value: isAdmin,
                      onChanged: (v) =>
                          setDialogState(() => isAdmin = v ?? false),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Отмена'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Сохранить'),
              ),
            ],
          );
        },
      ),
    );

    if (result != true || !mounted) return;

    final name = nameController.text.trim();
    if (name.length < 2) {
      _showSnack('Имя от 2 до 100 символов', Colors.orange);
      return;
    }

    try {
      await ref.read(userServiceProvider).updateUser(
        user.id,
        name,
        password: passwordController.text.isNotEmpty
            ? passwordController.text
            : null,
        isAdmin: ApiConfig.isAdmin ? isAdmin : null,
      );
      if (mounted) {
        _showSnack('Пользователь обновлён', Colors.green);
        ref.invalidate(usersProvider);
      }
    } catch (e) {
      _showSnack('Ошибка: $e', Colors.red);
    }
  }

  Future<void> _confirmDelete(User user) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить пользователя?'),
        content: Text(
          'Пользователь "${user.name}" будет удалён. Это действие необратимо.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (result != true || !mounted) return;

    try {
      await ref.read(userServiceProvider).deleteUser(user.id);
      if (mounted) {
        _showSnack('Пользователь удалён', Colors.green);
        ref.invalidate(usersProvider);
      }
    } catch (e) {
      _showSnack('Ошибка: $e', Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(usersProvider);
    if (!ApiConfig.isLoggedIn || !ApiConfig.isAdmin) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Пользователи', style: AppTheme.appBarTitle),
          backgroundColor: AppTheme.appBarBackground,
          foregroundColor: AppTheme.appBarForeground,
        ),
        body: const Center(
          child: Text(
            'Требуются права администратора.\nВойдите под учётной записью администратора.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Пользователи', style: AppTheme.appBarTitle),
        backgroundColor: AppTheme.appBarBackground,
        foregroundColor: AppTheme.appBarForeground,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: usersAsync.isLoading ? null : _refreshUsers,
          ),
        ],
      ),
      body: _buildBody(usersAsync),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody(AsyncValue<List<User>> usersAsync) {
    return usersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _UsersErrorState(
        error: error.toString(),
        onRetry: _refreshUsers,
      ),
      data: (users) {
        if (users.isEmpty) {
          return const _UsersEmptyState();
        }
        return _UsersList(
          users: users,
          onRefresh: _refreshUsers,
          onEdit: _showEditDialog,
          onDelete: _confirmDelete,
        );
      },
    );
  }
}

class _UsersErrorState extends StatelessWidget {
  const _UsersErrorState({
    required this.error,
    required this.onRetry,
  });

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red[400]),
            const SizedBox(height: 16),
            Text(error, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Повторить'),
            ),
          ],
        ),
      ),
    );
  }
}

class _UsersEmptyState extends StatelessWidget {
  const _UsersEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Нет пользователей',
            style: TextStyle(fontSize: 18, color: Colors.grey[700]),
          ),
          const SizedBox(height: 8),
          Text(
            'Нажмите + чтобы добавить',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}

class _UsersList extends StatelessWidget {
  const _UsersList({
    required this.users,
    required this.onRefresh,
    required this.onEdit,
    required this.onDelete,
  });

  final List<User> users;
  final Future<void> Function() onRefresh;
  final ValueChanged<User> onEdit;
  final ValueChanged<User> onDelete;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: users.length,
        itemBuilder: (context, index) {
          final user = users[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                child: Text(user.name.isNotEmpty ? user.name[0].toUpperCase() : '?'),
              ),
              title: Row(
                children: [
                  Expanded(child: Text(user.name)),
                  if (user.isAdmin)
                    Chip(
                      label: const Text('Админ', style: TextStyle(fontSize: 11)),
                      backgroundColor: Colors.amber[100],
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                ],
              ),
              trailing: PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') onEdit(user);
                  if (value == 'delete') onDelete(user);
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'edit', child: Text('Редактировать')),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Удалить', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
              onTap: () => onEdit(user),
            ),
          );
        },
      ),
    );
  }
}
