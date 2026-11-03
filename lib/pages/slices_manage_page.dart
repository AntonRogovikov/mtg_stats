import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mtg_stats/core/app_theme.dart';
import 'package:mtg_stats/models/slice.dart';
import 'package:mtg_stats/providers/service_providers.dart';
import 'package:mtg_stats/providers/slice_providers.dart';
import 'package:mtg_stats/services/api_config.dart';
import 'package:mtg_stats/widgets/common/async_state_views.dart';

/// Палитра цветов разреза: тёмные тона, читаемые с белым текстом.
/// Пустая строка — стандартная синяя гамма приложения.
const List<String> sliceColorPalette = [
  '',
  '#C62828', // красный
  '#AD1457', // малиновый
  '#6A1B9A', // фиолетовый
  '#4527A0', // тёмно-фиолетовый
  '#283593', // индиго
  '#1565C0', // синий
  '#00695C', // бирюзовый
  '#2E7D32', // зелёный
  '#EF6C00', // оранжевый
  '#4E342E', // коричневый
];

/// Управление разрезами (только админ): список, создание, изменение, удаление.
class SlicesManagePage extends ConsumerWidget {
  const SlicesManagePage({super.key});

  Future<void> _delete(BuildContext context, WidgetRef ref, Slice slice) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить разрез?'),
        content: Text(
          slice.gamesCount > 0
              ? 'Разрез «${slice.name}» и ВСЕ его игры (${slice.gamesCount}) '
                  'будут удалены безвозвратно вместе со статистикой.'
              : 'Разрез «${slice.name}» будет удалён безвозвратно.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(sliceServiceProvider).deleteSlice(slice.id);
      ref.invalidate(slicesProvider);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slicesAsync = ref.watch(slicesProvider);

    if (!ApiConfig.isAdmin) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Разрезы', style: AppTheme.appBarTitle),
          backgroundColor: AppTheme.appBarBackground,
          foregroundColor: AppTheme.appBarForeground,
        ),
        body: const Center(
          child: Text(
            'Управлять разрезами могут только администраторы.',
            style: TextStyle(fontSize: 16, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Управление разрезами', style: AppTheme.appBarTitle),
        backgroundColor: AppTheme.appBarBackground,
        foregroundColor: AppTheme.appBarForeground,
        elevation: 4,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(slicesProvider),
          ),
        ],
      ),
      backgroundColor: Colors.grey[100],
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.appBarBackground,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Новый разрез'),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SliceEditPage()),
        ),
      ),
      body: slicesAsync.when(
        loading: () => const AsyncLoadingView(),
        error: (error, _) => AsyncErrorView(
          message: error.toString(),
          onRetry: () => ref.invalidate(slicesProvider),
        ),
        data: (slices) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
          children: slices.map((s) {
            final color = s.themeColor ?? AppTheme.appBarBackground;
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: color,
                  child: Icon(
                    s.isDefault ? Icons.public : Icons.dashboard_customize,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                title: Text(
                  s.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  'Колод: ${s.deckIds.length} • Игр: ${s.gamesCount}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      tooltip: s.isDefault
                          ? 'Изменить имя и цвет'
                          : 'Изменить разрез',
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SliceEditPage(slice: s),
                        ),
                      ),
                    ),
                    if (!s.isDefault)
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.red),
                        tooltip: s.gamesCount > 0
                            ? 'Удалить разрез и все его игры'
                            : 'Удалить разрез',
                        onPressed: () => _delete(context, ref, s),
                      ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

/// Создание/редактирование разреза: имя, цвет, пул колод (мин. 4), игроки.
class SliceEditPage extends ConsumerStatefulWidget {
  const SliceEditPage({super.key, this.slice});

  /// null — создание нового разреза.
  final Slice? slice;

  @override
  ConsumerState<SliceEditPage> createState() => _SliceEditPageState();
}

class _SliceEditPageState extends ConsumerState<SliceEditPage> {
  late final TextEditingController _nameController;
  late String _color;
  late final Set<int> _selectedDeckIds;
  late final Set<int> _excludedDeckIds;
  int? _togglingDeckId;
  bool _saving = false;

  bool get _isEdit => widget.slice != null;
  bool get _isDefault => widget.slice?.isDefault ?? false;

  /// Колоды, по которым в разрезе уже есть игры: их нельзя убрать из пула
  /// (добавлять новые колоды можно свободно).
  Set<int> get _lockedDeckIds => {...?widget.slice?.usedDeckIds};

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.slice?.name ?? '');
    _color = widget.slice?.color ?? '';
    _selectedDeckIds = {...?widget.slice?.deckIds};
    _excludedDeckIds = {...?widget.slice?.excludedDeckIds};
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Color _paletteColor(String hex) {
    if (hex.isEmpty) return Colors.blueGrey[900]!;
    return Color(0xFF000000 | int.parse(hex.substring(1), radix: 16));
  }

  Future<void> _toggleExclude(int deckId, bool exclude) async {
    final slice = widget.slice;
    if (slice == null) return;
    setState(() => _togglingDeckId = deckId);
    try {
      final updated = await ref
          .read(sliceServiceProvider)
          .setExcludeFromDraw(slice.id, deckId, exclude);
      if (!mounted) return;
      setState(() {
        _excludedDeckIds
          ..clear()
          ..addAll(updated.excludedDeckIds);
      });
      ref.invalidate(slicesProvider);
    } catch (e) {
      _showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _togglingDeckId = null);
    }
  }

  Widget _excludeSwitch(int deckId) {
    final saved = widget.slice?.deckIds.contains(deckId) ?? false;
    if (!saved) return const SizedBox.shrink();
    return Tooltip(
      message: 'Запретить выбор в этом разрезе: и кубик, и ручной ввод',
      child: SizedBox(
        width: 36,
        height: 20,
        child: FittedBox(
          fit: BoxFit.contain,
          child: Switch(
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            value: _excludedDeckIds.contains(deckId),
            onChanged: _togglingDeckId == deckId
                ? null
                : (value) => _toggleExclude(deckId, value),
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.length < 2) {
      _showError('Название должно быть не короче 2 символов');
      return;
    }
    if (!_isDefault && _selectedDeckIds.length < 4) {
      _showError('Выберите минимум 4 колоды — по числу игроков');
      return;
    }
    setState(() => _saving = true);
    try {
      final service = ref.read(sliceServiceProvider);
      final slice = Slice(
        id: widget.slice?.id ?? 0,
        name: name,
        color: _color,
        deckIds: _selectedDeckIds.toList()..sort(),
        playerIds: const [], // пока всегда все игроки — бэкенд заполнит сам
      );
      if (_isEdit) {
        await service.updateSlice(slice);
      } else {
        await service.createSlice(slice);
      }
      ref.invalidate(slicesProvider);
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      _showError('$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final decksAsync = ref.watch(decksProvider);
    final usersAsync = ref.watch(usersProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEdit ? 'Разрез: ${widget.slice!.name}' : 'Новый разрез',
          style: AppTheme.appBarTitle,
        ),
        backgroundColor: AppTheme.appBarBackground,
        foregroundColor: AppTheme.appBarForeground,
        elevation: 4,
      ),
      backgroundColor: Colors.grey[100],
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Название',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nameController,
                    maxLength: 100,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Например: Сезон 2026',
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Цвет разреза',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Первый — стандартная гамма приложения.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: sliceColorPalette.map((hex) {
                      final selected = _color == hex;
                      return GestureDetector(
                        onTap: () => setState(() => _color = hex),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: _paletteColor(hex),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: selected
                                  ? Colors.black
                                  : Colors.grey.shade300,
                              width: selected ? 3 : 1,
                            ),
                          ),
                          child: selected
                              ? const Icon(Icons.check,
                                  color: Colors.white, size: 22)
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Игроки',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Пока в каждом разрезе играют все четверо.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  usersAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text('Не удалось загрузить игроков: $e'),
                    data: (users) => Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: users
                          .map((u) => Chip(
                                avatar: const Icon(Icons.person, size: 18),
                                label: Text(u.name),
                              ))
                          .toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_isDefault)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'В основном разрезе доступны все колоды, кроме тех, что входят в пул другого разреза. Новая колода появляется здесь, пока её не добавят в другой разрез. Переключатель «Не выбирать» запрещает и автовыбор, и ручной ввод.',
                      style: TextStyle(color: Colors.grey),
                    ),
                    if (_isEdit) ...[
                      const SizedBox(height: 12),
                      decksAsync.when(
                        loading: () => const LinearProgressIndicator(),
                        error: (e, _) => Text('Не удалось загрузить колоды: $e'),
                        data: (decks) {
                          final pool = widget.slice!.deckIds.toSet();
                          final sorted = decks
                              .where((d) => pool.contains(d.id))
                              .toList()
                            ..sort((a, b) => a.name.compareTo(b.name));
                          return Column(
                            children: sorted
                                .map((d) => ListTile(
                                      dense: true,
                                      visualDensity: VisualDensity.compact,
                                      minTileHeight: 36,
                                      contentPadding: EdgeInsets.zero,
                                      title: Text(d.name),
                                      trailing: _excludeSwitch(d.id),
                                    ))
                                .toList(),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            )
          else
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Пул колод',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          'Выбрано: ${_selectedDeckIds.length} (мин. 4)',
                          style: TextStyle(
                            fontSize: 13,
                            color: _selectedDeckIds.length >= 4
                                ? Colors.green[700]
                                : Colors.red[700],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (_lockedDeckIds.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.shade300),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.lock_outline,
                                size: 18, color: Colors.orange.shade800),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Колоды с играми (🔒) убрать из разреза нельзя. '
                                'Их можно пометить «Не выбирать»: тогда их не возьмут ни кубик, ни ручной ввод.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.orange.shade900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else
                      const Text(
                        'В разрезе будут доступны только выбранные колоды.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    const SizedBox(height: 8),
                    decksAsync.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (e, _) => Text('Не удалось загрузить колоды: $e'),
                      data: (decks) {
                        final sorted = [...decks]
                          ..sort((a, b) => a.name.compareTo(b.name));
                        return Column(
                          children: sorted.map((d) {
                            final isSelected = _selectedDeckIds.contains(d.id);
                            // Блокируем снятие только для колод, что и в пуле, и с играми.
                            final isLocked =
                                isSelected && _lockedDeckIds.contains(d.id);
                            return CheckboxListTile(
                              dense: true,
                              visualDensity: VisualDensity.compact,
                              contentPadding: EdgeInsets.zero,
                              controlAffinity: ListTileControlAffinity.leading,
                              title: Text(d.name),
                              secondary: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _excludeSwitch(d.id),
                                  if (isLocked) ...[
                                    const SizedBox(width: 4),
                                    Icon(Icons.lock_outline,
                                        size: 16,
                                        color: Colors.orange.shade700),
                                  ],
                                ],
                              ),
                              value: isSelected,
                              // Колоду с играми снять нельзя; добавлять — свободно.
                              onChanged: isLocked
                                  ? null
                                  : (checked) => setState(() {
                                        if (checked == true) {
                                          _selectedDeckIds.add(d.id);
                                        } else {
                                          _selectedDeckIds.remove(d.id);
                                        }
                                      }),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 24),
          SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.appBarBackground,
                foregroundColor: Colors.white,
              ),
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save),
              label: Text(_isEdit ? 'Сохранить' : 'Создать разрез'),
            ),
          ),
        ],
      ),
    );
  }
}
