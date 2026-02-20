# MTG Stats

Flutter-приложение для учёта статистики партий Magic: The Gathering. Таймеры ходов, история игр, статистика по игрокам и колодам.

## Структура проекта

```
mtg_stats/
├── lib/
│   ├── main.dart                 # Точка входа, маршрутизация, ResponsiveWebLayout
│   │
│   ├── core/                     # Общие утилиты и конфигурация
│   │   ├── api_error.dart       # Парсинг ошибок API
│   │   ├── app_theme.dart       # Тема приложения
│   │   ├── constants.dart       # Константы
│   │   ├── format_utils.dart    # Форматирование времени, чисел
│   │   ├── platform_utils.dart  # Условный экспорт: web vs IO
│   │   ├── platform_utils_web.dart
│   │   └── platform_utils_stub.dart
│   │
│   ├── data/
│   │   └── fun_team_names.dart  # Случайные названия команд
│   │
│   ├── models/                  # Модели данных
│   │   ├── deck.dart
│   │   ├── game.dart
│   │   ├── stats.dart
│   │   └── user.dart
│   │
│   ├── pages/                   # Экраны приложения
│   │   ├── home_page.dart       # Главная навигация
│   │   ├── game_page.dart      # Настройка новой игры
│   │   ├── active_game_page.dart # Активная партия (таймеры, ходы)
│   │   ├── games_history_page.dart # История игр
│   │   ├── stats_page.dart     # Статистика
│   │   ├── decks_page.dart     # Список колод
│   │   ├── deck_card_page.dart # Карточка колоды
│   │   ├── deck_picker_page.dart
│   │   ├── deck_selection_page.dart
│   │   ├── full_screen_image_page.dart
│   │   ├── settings_page.dart  # Настройки, экспорт/импорт
│   │   ├── change_password_page.dart
│   │   └── users_page.dart     # Управление пользователями (админ)
│   │
│   ├── services/                # API и бизнес-логика
│   │   ├── api_config.dart     # Base URL, JWT, SharedPreferences
│   │   ├── auth_service.dart   # Логин
│   │   ├── game_service.dart   # CRUD игр, активная игра
│   │   ├── game_manager.dart   # Синглтон состояния активной игры
│   │   ├── deck_service.dart   # CRUD колод
│   │   ├── user_service.dart  # CRUD пользователей
│   │   ├── stats_service.dart # Статистика
│   │   ├── health_service.dart # Проверка бэкенда
│   │   ├── maintenance_service.dart # Экспорт, импорт, очистка
│   │   └── deck_image/         # Изображения колод (web vs IO)
│   │
│   └── widgets/                 # Переиспользуемые виджеты
│       ├── responsive_web_layout.dart
│       ├── home_button.dart
│       ├── deck_card.dart
│       └── stats/               # Графики статистики
│
├── assets/
│   ├── images/
│   └── audio/
│
├── android/, ios/, linux/, macos/, web/, windows/  # Платформенные конфигурации
└── pubspec.yaml
```

## Архитектура

- **Паттерн:** MVC-подобный: страницы (StatefulWidget), сервисы, модели.
- **Маршрутизация:** Named routes в MaterialApp.
- **Состояние:** GameManager — синглтон для активной игры; ApiConfig — статическая конфигурация; setState в виджетах.
- **Бэкенд:** REST API (пакет http), baseUrl и auth через ApiConfig.

## Платформы

Android, iOS, Linux, macOS, Windows, Web.

## Запуск

```bash
flutter pub get
flutter run
```

Для web с кастомным бэкендом:
```bash
flutter run -d chrome --dart-define=BASE_URL=https://your-backend.com
```

## Зависимости

- `http` — HTTP-клиент
- `shared_preferences` — хранение настроек
- `fl_chart` — графики статистики
- `image_picker`, `image` — загрузка изображений колод
- `audioplayers` — звуки таймера
- `file_selector` — выбор файлов (web)
- `stop_watch_timer` — таймеры
